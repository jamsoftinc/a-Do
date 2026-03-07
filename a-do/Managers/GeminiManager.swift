//
//  GeminiManager.swift
//  a-do
//
//  Firebase AI Logic client for Gemini-backed Pro features.
//

import FirebaseAILogic
import FirebaseCore
import FirebaseRemoteConfig
import Foundation
import Observation
import os

enum GeminiAPIError: LocalizedError {
    case proRequired
    case firebaseNotConfigured
    case invalidModelConfiguration
    case rateLimited
    case invalidResponse
    case apiError(message: String)

    var errorDescription: String? {
        switch self {
        case .proRequired:
            return "Gemini requires a Pro subscription."
        case .firebaseNotConfigured:
            return "Firebase AI is not configured. Add GoogleService-Info.plist to the app target and enable Firebase AI Logic."
        case .invalidModelConfiguration:
            return "No valid Gemini model is configured."
        case .rateLimited:
            return "Gemini requests are temporarily rate limited."
        case .invalidResponse:
            return "Gemini returned an invalid response."
        case let .apiError(message):
            return "Gemini API error: \(message)"
        }
    }
}

private struct RemoteGeminiModel: Decodable {
    let id: String?
    let model: String?
    let name: String?
}

@MainActor
@Observable
final class GeminiManager {
    static let shared = GeminiManager()

    private let logger = Logger(subsystem: "a-do", category: "Gemini")
    private let remoteConfigModelListKey = "gemini_model_list"
    private let remoteConfigMinimumFetchInterval: TimeInterval = 3600
    private let remoteConfigFetchTimeout: TimeInterval = 10

    private var didConfigureRemoteConfig = false

    var isConfigured: Bool = false
    var isProcessing: Bool = false
    var isRemoteConfigReady: Bool = false
    var availableModelIDs: [String] = []
    var lastError: String?

    var modelID: String? {
        availableModelIDs.first
    }

    private init() {
        _ = refreshConfigurationStatus()
    }

    // MARK: - Configuration

    func bootstrapIfNeeded() {
        guard refreshConfigurationStatus() else { return }

        Task {
            await refreshRemoteConfiguration()
        }
    }

    /// Compatibility wrapper for older call sites.
    func bootstrapAPIKeyIfNeeded() {
        bootstrapIfNeeded()
    }

    @discardableResult
    func refreshConfigurationStatus() -> Bool {
        guard FirebaseApp.app() != nil else {
            isConfigured = false
            isRemoteConfigReady = false
            availableModelIDs = []
            lastError = GeminiAPIError.firebaseNotConfigured.localizedDescription
            return false
        }

        configureRemoteConfigIfNeeded()
        updateAvailableModelsFromRemoteConfig()

        isConfigured = true
        lastError = nil
        return true
    }

    func refreshRemoteConfiguration() async {
        guard refreshConfigurationStatus(), let remoteConfig else { return }

        do {
            _ = try await remoteConfig.fetchAndActivate()
            updateAvailableModelsFromRemoteConfig()
            lastError = nil
        } catch {
            logger.error("Remote Config fetch failed: \(error.localizedDescription)")
            updateAvailableModelsFromRemoteConfig()
            lastError = "Remote Config fetch failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Generation

    func generateStructuredResponse<T: Decodable>(
        prompt: String,
        as type: T.Type,
        modelOverride: String? = nil,
        temperature: Double = 0.2,
        maxOutputTokens: Int = 1024
    ) async throws -> T {
        let raw = try await generateText(
            prompt: prompt,
            modelOverride: modelOverride,
            responseMimeType: "application/json",
            temperature: temperature,
            maxOutputTokens: maxOutputTokens
        )

        guard let jsonPayload = extractJSONObjectString(from: raw),
              let jsonData = jsonPayload.data(using: .utf8) else {
            throw GeminiAPIError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(type, from: jsonData)
        } catch {
            logger.error("Gemini JSON decode failed: \(error.localizedDescription)")
            throw GeminiAPIError.invalidResponse
        }
    }

    func generateText(
        prompt: String,
        modelOverride: String? = nil,
        responseMimeType: String = "text/plain",
        temperature: Double = 0.2,
        maxOutputTokens: Int = 1024
    ) async throws -> String {
        guard EntitlementManager.shared.isProUser else {
            throw GeminiAPIError.proRequired
        }

        let rateLimitKey = "gemini_api_\(SecurityUtils.getCurrentUserID())"
        guard SecurityUtils.isWithinRateLimit(key: rateLimitKey, maxAttempts: 20, timeWindow: 60) else {
            throw GeminiAPIError.rateLimited
        }

        guard refreshConfigurationStatus() else {
            throw GeminiAPIError.firebaseNotConfigured
        }

        let requestedModel = modelOverride ?? modelID
        guard let modelName = validatedGeminiModelID(requestedModel) else {
            throw GeminiAPIError.invalidModelConfiguration
        }

        let generationConfig = GenerationConfig(
            temperature: Float(max(0.0, min(1.0, temperature))),
            maxOutputTokens: max(128, maxOutputTokens),
            responseMIMEType: responseMimeType
        )

        let model = FirebaseAI.firebaseAI().generativeModel(
            modelName: modelName,
            generationConfig: generationConfig
        )

        isProcessing = true
        defer { isProcessing = false }

        do {
            let response = try await model.generateContent(prompt)
            guard let responseText = response.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !responseText.isEmpty else {
                throw GeminiAPIError.invalidResponse
            }

            lastError = nil
            return responseText
        } catch let error as GeminiAPIError {
            lastError = error.localizedDescription
            throw error
        } catch {
            logger.error("Firebase AI request failed: \(error.localizedDescription)")
            let mappedError = mapFirebaseError(error)
            lastError = mappedError.localizedDescription
            throw mappedError
        }
    }

    // MARK: - Internal Helpers

    private var remoteConfig: RemoteConfig? {
        guard FirebaseApp.app() != nil else { return nil }
        return RemoteConfig.remoteConfig()
    }

    private func configureRemoteConfigIfNeeded() {
        guard !didConfigureRemoteConfig, let remoteConfig else { return }

        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = remoteConfigMinimumFetchInterval
        settings.fetchTimeout = remoteConfigFetchTimeout
        remoteConfig.configSettings = settings

        didConfigureRemoteConfig = true
    }

    private func updateAvailableModelsFromRemoteConfig() {
        let parsedModels = parseRemoteModelList(from: remoteConfig?.configValue(forKey: remoteConfigModelListKey).stringValue)
        availableModelIDs = parsedModels
        isRemoteConfigReady = !parsedModels.isEmpty
    }

    private func parseRemoteModelList(from rawValue: String?) -> [String] {
        guard let rawValue = sanitizedConfigurationValue(rawValue) else {
            return []
        }

        if let jsonData = rawValue.data(using: .utf8) {
            if let decodedStrings = try? JSONDecoder().decode([String].self, from: jsonData) {
                return deduplicatedValidatedModels(decodedStrings)
            }

            if let decodedObjects = try? JSONDecoder().decode([RemoteGeminiModel].self, from: jsonData) {
                let rawModels = decodedObjects.compactMap { candidate in
                    candidate.id ?? candidate.model ?? candidate.name
                }
                return deduplicatedValidatedModels(rawModels)
            }
        }

        let delimitedModels = rawValue
            .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == ";" })
            .map { String($0) }

        return deduplicatedValidatedModels(delimitedModels)
    }

    private func deduplicatedValidatedModels(_ models: [String]) -> [String] {
        var seen: Set<String> = []
        var validatedModels: [String] = []

        for candidate in models {
            guard let normalized = validatedGeminiModelID(candidate), seen.insert(normalized).inserted else {
                continue
            }
            validatedModels.append(normalized)
        }

        return validatedModels
    }

    private func mapFirebaseError(_ error: Error) -> GeminiAPIError {
        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        if description.contains("429") || description.localizedCaseInsensitiveContains("rate") {
            return .rateLimited
        }

        if description.localizedCaseInsensitiveContains("FirebaseApp")
            || description.localizedCaseInsensitiveContains("GoogleService-Info")
            || description.localizedCaseInsensitiveContains("app was found") {
            return .firebaseNotConfigured
        }

        return .apiError(message: description.isEmpty ? "Unknown Firebase AI error" : description)
    }

    private func extractJSONObjectString(from raw: String) -> String? {
        let strippedFence = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```JSON", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if strippedFence.hasPrefix("{"), strippedFence.hasSuffix("}") {
            return strippedFence
        }

        guard let start = strippedFence.firstIndex(of: "{"),
              let end = strippedFence.lastIndex(of: "}") else {
            return nil
        }

        return String(strippedFence[start...end])
    }

    private func sanitizedConfigurationValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func validatedGeminiModelID(_ value: String?) -> String? {
        guard let normalized = sanitizedConfigurationValue(value)?.lowercased() else { return nil }
        guard normalized.hasPrefix("gemini-"), normalized.count > "gemini-".count else {
            return nil
        }

        return normalized
    }
}
