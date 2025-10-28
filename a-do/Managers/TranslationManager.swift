//
//  TranslationManager.swift
//  a-do
//
//  Multi-language translation for collaboration and reminders
//

import Foundation
import Translation
import SwiftData
import Observation
import os

@MainActor
@Observable
final class TranslationManager {
    static let shared = TranslationManager()

    private let logger = Logger(subsystem: "a-do", category: "Translation")

    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.isProUser
    }

    // Translation settings
    var autoTranslateEnabled: Bool = false
    var preferredLanguage: SupportedLanguage = .english
    var translationCache: [String: TranslationCacheEntry] = [:]

    // Collaboration translation
    var translateSharedReminders: Bool = true
    var translateComments: Bool = true

    private init() {
        loadPreferences()
    }

    // MARK: - Translation

    @available(iOS 17.4, *)
    func translate(
        text: String,
        from sourceLanguage: SupportedLanguage? = nil,
        to targetLanguage: SupportedLanguage
    ) async -> String? {
        guard isProEnabled else {
            logger.warning("Translation is a Pro feature")
            return nil
        }

        // Check cache first
        let cacheKey = "\(text)_\(sourceLanguage?.code ?? "auto")_\(targetLanguage.code)"
        if let cached = translationCache[cacheKey], !cached.isExpired {
            logger.info("Returning cached translation")
            return cached.translatedText
        }

        do {
            let targetLocale = targetLanguage.locale

            // For iOS 17.4+, use basic translation
            // Note: In production, you'd use the full Translation framework API
            // For now, we'll use a simplified approach compatible with iOS 17.4
            if #available(iOS 26.0, *) {
                let sourceLocale = sourceLanguage?.locale
                let session = TranslationSession(
                    installedSource: sourceLocale?.language ?? targetLocale.language,
                    target: targetLocale.language
                )
                let response = try await session.translate(text)

                // Cache the result
                translationCache[cacheKey] = TranslationCacheEntry(
                    translatedText: response.targetText,
                    timestamp: Date()
                )

                logger.info("Translation successful: \(sourceLanguage?.displayName ?? "auto") -> \(targetLanguage.displayName)")
                return response.targetText
            } else {
                // For iOS 17.4-25.x, translation requires system UI
                // Return placeholder indicating translation not available in background
                logger.warning("Translation requires iOS 26.0 for programmatic API. Current iOS version doesn't support background translation.")
                return nil
            }

        } catch {
            logger.error("Translation failed: \(error.localizedDescription)")
            return nil
        }
    }

    func translateReminder(_ reminder: Reminder, to targetLanguage: SupportedLanguage, context: ModelContext) async -> Reminder? {
        guard isProEnabled else {
            logger.warning("Reminder translation is a Pro feature")
            return nil
        }

        guard #available(iOS 17.4, *) else {
            logger.warning("Translation requires iOS 17.4 or later")
            return nil
        }

        // Translate title
        guard let translatedTitle = await translate(
            text: reminder.title,
            to: targetLanguage
        ) else {
            return nil
        }

        // Translate details if present
        var translatedDetails: String?
        if let details = reminder.details {
            translatedDetails = await translate(
                text: details,
                to: targetLanguage
            )
        }

        // Create translated copy
        let translatedReminder = Reminder(
            title: translatedTitle,
            details: translatedDetails,
            dueDate: reminder.dueDate,
            priority: reminder.priority
        )

        context.insert(translatedReminder)

        do {
            try context.save()
            logger.info("Created translated reminder in \(targetLanguage.displayName)")
            return translatedReminder
        } catch {
            logger.error("Failed to save translated reminder: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Language Detection

    @available(iOS 17.4, *)
    func detectLanguage(in text: String) async -> SupportedLanguage? {
        guard isProEnabled else {
            logger.warning("Language detection is a Pro feature")
            return nil
        }

        // Use NaturalLanguage framework for detection
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let dominantLanguage = recognizer.dominantLanguage else {
            return nil
        }

        // Map to supported language
        return SupportedLanguage.from(nlLanguage: dominantLanguage)
    }

    // MARK: - Batch Translation

    func translateMultiple(
        texts: [String],
        to targetLanguage: SupportedLanguage
    ) async -> [String?] {
        guard isProEnabled else {
            logger.warning("Batch translation is a Pro feature")
            return Array(repeating: nil, count: texts.count)
        }

        guard #available(iOS 17.4, *) else {
            logger.warning("Translation requires iOS 17.4 or later")
            return Array(repeating: nil, count: texts.count)
        }

        var results: [String?] = []

        for text in texts {
            let translated = await translate(text: text, to: targetLanguage)
            results.append(translated)
        }

        return results
    }

    // MARK: - Collaboration Integration

    func translateSharedContent(
        content: String,
        fromLanguage: SupportedLanguage,
        forUsers: [String: SupportedLanguage]
    ) async -> [String: String] {
        guard isProEnabled else {
            logger.warning("Collaboration translation is a Pro feature")
            return [:]
        }

        guard #available(iOS 17.4, *) else {
            return [:]
        }

        var translations: [String: String] = [:]

        for (userId, targetLanguage) in forUsers {
            if targetLanguage == fromLanguage {
                // No translation needed
                translations[userId] = content
            } else {
                if let translated = await translate(
                    text: content,
                    from: fromLanguage,
                    to: targetLanguage
                ) {
                    translations[userId] = translated
                }
            }
        }

        return translations
    }

    // MARK: - Settings

    private func loadPreferences() {
        // Load from UserDefaults
        autoTranslateEnabled = UserDefaults.standard.bool(forKey: "translation.autoTranslate")
        translateSharedReminders = UserDefaults.standard.bool(forKey: "translation.shareReminders")
        translateComments = UserDefaults.standard.bool(forKey: "translation.comments")

        if let languageCode = UserDefaults.standard.string(forKey: "translation.preferredLanguage"),
           let language = SupportedLanguage.from(code: languageCode) {
            preferredLanguage = language
        }
    }

    func savePreferences() {
        UserDefaults.standard.set(autoTranslateEnabled, forKey: "translation.autoTranslate")
        UserDefaults.standard.set(translateSharedReminders, forKey: "translation.shareReminders")
        UserDefaults.standard.set(translateComments, forKey: "translation.comments")
        UserDefaults.standard.set(preferredLanguage.code, forKey: "translation.preferredLanguage")
    }

    // MARK: - Cache Management

    func clearCache() {
        translationCache.removeAll()
        logger.info("Translation cache cleared")
    }

    func clearExpiredCache() {
        let expired = translationCache.filter { $0.value.isExpired }
        for key in expired.keys {
            translationCache.removeValue(forKey: key)
        }
        logger.info("Cleared \(expired.count) expired cache entries")
    }
}

// MARK: - Supporting Types

enum SupportedLanguage: String, CaseIterable, Codable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"
    case japanese = "ja"
    case korean = "ko"
    case chinese = "zh"
    case arabic = "ar"
    case hindi = "hi"
    case dutch = "nl"
    case swedish = "sv"
    case polish = "pl"
    case turkish = "tr"
    case vietnamese = "vi"
    case thai = "th"
    case indonesian = "id"
    case danish = "da"

    var code: String {
        return rawValue
    }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .russian: return "Russian"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .chinese: return "Chinese"
        case .arabic: return "Arabic"
        case .hindi: return "Hindi"
        case .dutch: return "Dutch"
        case .swedish: return "Swedish"
        case .polish: return "Polish"
        case .turkish: return "Turkish"
        case .vietnamese: return "Vietnamese"
        case .thai: return "Thai"
        case .indonesian: return "Indonesian"
        case .danish: return "Danish"
        }
    }

    var locale: Locale {
        return Locale(identifier: rawValue)
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇵🇹"
        case .russian: return "🇷🇺"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .chinese: return "🇨🇳"
        case .arabic: return "🇸🇦"
        case .hindi: return "🇮🇳"
        case .dutch: return "🇳🇱"
        case .swedish: return "🇸🇪"
        case .polish: return "🇵🇱"
        case .turkish: return "🇹🇷"
        case .vietnamese: return "🇻🇳"
        case .thai: return "🇹🇭"
        case .indonesian: return "🇮🇩"
        case .danish: return "🇩🇰"
        }
    }

    static func from(code: String) -> SupportedLanguage? {
        return SupportedLanguage(rawValue: code)
    }

    static func from(nlLanguage: NLLanguage) -> SupportedLanguage? {
        let code = nlLanguage.rawValue
        return SupportedLanguage(rawValue: code)
    }
}

struct TranslationCacheEntry {
    let translatedText: String
    let timestamp: Date
    let cacheLifetime: TimeInterval = 3600 // 1 hour

    var isExpired: Bool {
        return Date().timeIntervalSince(timestamp) > cacheLifetime
    }
}

import NaturalLanguage
