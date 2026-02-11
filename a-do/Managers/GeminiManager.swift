//
//  GeminiManager.swift
//  a-do
//
//  Google Gemini API client for Pro users.
//  NOTE: Without a backend proxy, API keys shipped in-app are at risk of extraction.
//

import Foundation
import Observation
import os

enum GeminiAPIError: LocalizedError {
    case proRequired
    case missingAPIKey
    case rateLimited
    case invalidEndpoint
    case unsupportedModelVersion
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .proRequired:
            return "Gemini requires a Pro subscription."
        case .missingAPIKey:
            return "Gemini API key is not configured."
        case .rateLimited:
            return "Gemini requests are temporarily rate limited."
        case .invalidEndpoint:
            return "Invalid Gemini endpoint configuration."
        case .unsupportedModelVersion:
            return "Only Gemini 3 and later models are allowed."
        case .invalidResponse:
            return "Gemini returned an invalid response."
        case let .apiError(statusCode, message):
            return "Gemini API error (\(statusCode)): \(message)"
        }
    }
}

@MainActor
@Observable
final class GeminiManager {
    static let shared = GeminiManager()

    private let logger = Logger(subsystem: "a-do", category: "Gemini")
    private let keychainService = "com.ado.app.gemini"
    private let keychainAccount = "api-key"
    private let modelIDPreferenceKey = "gemini.model.id"
    private let defaultModelID = "gemini-3.0-flash"
    // Source-level fallback for App Store builds when Info.plist injection is unavailable.
    // This still has extraction risk; use quota limits and rotate as needed.
    private let sourceFallbackAPIKey = "AIzaSyBJSCzTW3w0IiqAnrfrjJRp-IZaxbLSWf4"

    var isConfigured: Bool = false
    var isProcessing: Bool = false
    var lastError: String?
    var hasBundledAPIKey: Bool {
        embeddedAPIKey() != nil
    }

    /// Uses bundle override first, then user-default override, then a safe default.
    var modelID: String {
        if let embedded = validatedGeminiModelID(Bundle.main.object(forInfoDictionaryKey: "GEMINI_MODEL_ID") as? String) {
            return embedded
        }

        if let preferred = validatedGeminiModelID(UserDefaults.standard.string(forKey: modelIDPreferenceKey)) {
            return preferred
        }

        return defaultModelID
    }

    private init() {
        _ = refreshConfigurationStatus()
    }

    // MARK: - Configuration

    func bootstrapAPIKeyIfNeeded() {
        _ = refreshConfigurationStatus()
    }

    @discardableResult
    func refreshConfigurationStatus() -> Bool {
        if let key = storedAPIKey(), !key.isEmpty {
            isConfigured = true
            return true
        }

        guard let embeddedKey = embeddedAPIKey() else {
            isConfigured = false
            return false
        }

        if SecurityUtils.storeSecret(embeddedKey, service: keychainService, account: keychainAccount) {
            logger.info("Gemini API key was loaded from app configuration.")
        } else {
            logger.error("Failed to persist Gemini API key into Keychain. Using bundled key fallback.")
        }

        // Treat bundled key as configured even if keychain persistence fails.
        isConfigured = true
        return true
    }

    /// Allows developer-only key provisioning flow (not exposed to end users).
    @discardableResult
    func setDeveloperAPIKey(_ key: String) -> Bool {
        guard let sanitized = sanitizedConfigurationValue(key) else {
            return false
        }

        let stored = SecurityUtils.storeSecret(sanitized, service: keychainService, account: keychainAccount)
        isConfigured = stored
        if !stored {
            lastError = "Failed to store Gemini API key"
        }
        return stored
    }

    @discardableResult
    func clearStoredAPIKey() -> Bool {
        let deleted = SecurityUtils.deleteSecret(service: keychainService, account: keychainAccount)
        isConfigured = false
        return deleted
    }

    func setPreferredModelID(_ modelID: String) {
        guard let sanitized = validatedGeminiModelID(modelID) else {
            lastError = GeminiAPIError.unsupportedModelVersion.localizedDescription
            return
        }
        UserDefaults.standard.set(sanitized, forKey: modelIDPreferenceKey)
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

        guard let apiKey = activeAPIKey() else {
            throw GeminiAPIError.missingAPIKey
        }

        let requestedModel = modelOverride ?? self.modelID
        guard let model = validatedGeminiModelID(requestedModel) else {
            throw GeminiAPIError.unsupportedModelVersion
        }
        guard let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw GeminiAPIError.invalidEndpoint
        }

        let requestPayload = GenerateContentRequest(
            contents: [
                .init(
                    role: "user",
                    parts: [.init(text: prompt)]
                )
            ],
            generationConfig: .init(
                responseMimeType: responseMimeType,
                temperature: max(0.0, min(1.0, temperature)),
                maxOutputTokens: max(128, maxOutputTokens)
            )
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(requestPayload)
        request.timeoutInterval = 30

        isProcessing = true
        defer { isProcessing = false }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiAPIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = parseErrorMessage(from: data) ?? "Unknown Gemini API error"
                logger.error("Gemini request failed with status \(httpResponse.statusCode): \(message)")
                throw GeminiAPIError.apiError(statusCode: httpResponse.statusCode, message: message)
            }

            let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
            let text = decoded.candidates?
                .first?
                .content?
                .parts
                .compactMap(\.text)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let responseText = text, !responseText.isEmpty else {
                throw GeminiAPIError.invalidResponse
            }

            return responseText
        } catch let error as GeminiAPIError {
            lastError = error.localizedDescription
            throw error
        } catch {
            logger.error("Gemini network/request error: \(error.localizedDescription)")
            lastError = error.localizedDescription
            throw GeminiAPIError.invalidResponse
        }
    }

    // MARK: - Internal Helpers

    private func activeAPIKey() -> String? {
        if !refreshConfigurationStatus() {
            return nil
        }

        if let key = storedAPIKey(), !key.isEmpty {
            return key
        }

        if let bundledKey = embeddedAPIKey() {
            return bundledKey
        }

        guard let key = storedAPIKey(), !key.isEmpty else {
            isConfigured = false
            return nil
        }

        isConfigured = true
        return key
    }

    private func embeddedAPIKey() -> String? {
        let candidates = ["GEMINI_API_KEY", "GOOGLE_GEMINI_API_KEY"]
        for candidate in candidates {
            if let value = sanitizedConfigurationValue(Bundle.main.object(forInfoDictionaryKey: candidate) as? String) {
                return value
            }
        }

        if let sourceValue = sanitizedConfigurationValue(sourceFallbackAPIKey) {
            logger.debug("Using source fallback Gemini API key")
            return sourceValue
        }

        return nil
    }

    private func storedAPIKey() -> String? {
        SecurityUtils.retrieveSecret(service: keychainService, account: keychainAccount)
    }

    private func parseErrorMessage(from data: Data) -> String? {
        guard let envelope = try? JSONDecoder().decode(GeminiErrorEnvelope.self, from: data) else {
            return nil
        }
        return envelope.error.message
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
        guard !trimmed.isEmpty else { return nil }

        // Ignore unresolved build setting placeholders.
        if trimmed.hasPrefix("$(") || trimmed.contains("GEMINI_API_KEY") {
            return nil
        }

        return trimmed
    }

    /// Accepts only Gemini model IDs with major version 3 or later.
    private func validatedGeminiModelID(_ value: String?) -> String? {
        guard let normalized = sanitizedConfigurationValue(value)?.lowercased() else { return nil }
        guard normalized.hasPrefix("gemini-") else { return nil }

        let suffix = normalized.dropFirst("gemini-".count)
        let majorDigits = String(suffix.prefix { $0.isNumber })
        guard let majorVersion = Int(majorDigits), majorVersion >= 3 else {
            return nil
        }

        return normalized
    }
}

// MARK: - Gemini API Payloads

private struct GenerateContentRequest: Encodable {
    let contents: [RequestContent]
    let generationConfig: GenerationConfig
}

private struct RequestContent: Encodable {
    let role: String
    let parts: [RequestPart]
}

private struct RequestPart: Encodable {
    let text: String
}

private struct GenerationConfig: Encodable {
    let responseMimeType: String
    let temperature: Double
    let maxOutputTokens: Int
}

private struct GenerateContentResponse: Decodable {
    let candidates: [Candidate]?
}

private struct Candidate: Decodable {
    let content: CandidateContent?
}

private struct CandidateContent: Decodable {
    let parts: [CandidatePart]
}

private struct CandidatePart: Decodable {
    let text: String?
}

private struct GeminiErrorEnvelope: Decodable {
    let error: GeminiErrorPayload
}

private struct GeminiErrorPayload: Decodable {
    let message: String
}
