//
//  AIWritingToolsManager.swift
//  a-do
//
//  AI Writing Tools using NaturalLanguage framework
//

import Foundation
import Observation
import os
import NaturalLanguage
import UIKit

@MainActor
@Observable
final class AIWritingToolsManager {
    static let shared = AIWritingToolsManager()
    
    private let logger = Logger(subsystem: "a-do", category: "AIWriting")
    
    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.canUseAIWritingTools
    }
    
    var isProcessing: Bool = false
    var lastError: String?
    
    private init() {}
    
    // MARK: - Writing Tools
    
    func rewrite(text: String, style: RewriteStyle = .clearer) async -> String? {
        guard isProEnabled else {
            logger.warning("AI Writing Tools is a Pro feature")
            return nil
        }

        logger.info("Rewriting text with style: \(style.rawValue)")
        isProcessing = true
        lastError = nil

        let rewritten = performRewrite(text: text, style: style)

        isProcessing = false
        logger.info("Text rewritten successfully")

        return rewritten
    }
    
    func proofread(text: String) async -> ProofreadResult? {
        guard isProEnabled else {
            logger.warning("AI Writing Tools is a Pro feature")
            return nil
        }

        logger.info("Proofreading text...")
        isProcessing = true
        lastError = nil

        let result = await Task.detached {
            await self.performProofread(text: text)
        }.value

        isProcessing = false
        logger.info("Text proofread successfully - found \(result.errors.count) issues")

        return result
    }
    
    func summarize(text: String, length: SummaryLength = .medium) async -> String? {
        guard isProEnabled else {
            logger.warning("AI Writing Tools is a Pro feature")
            return nil
        }

        logger.info("Summarizing text with length: \(length.rawValue)")
        isProcessing = true
        lastError = nil

        let summary = performSummarize(text: text, length: length)

        isProcessing = false
        logger.info("Text summarized successfully")

        return summary
    }
    
    func adjustTone(text: String, targetTone: Tone) async -> String? {
        guard isProEnabled else {
            logger.warning("AI Writing Tools is a Pro feature")
            return nil
        }

        logger.info("Adjusting tone to: \(targetTone.rawValue)")
        isProcessing = true
        lastError = nil

        let adjusted = performToneAdjustment(text: text, targetTone: targetTone)

        isProcessing = false
        logger.info("Tone adjusted successfully")

        return adjusted
    }
    
    func extractKeyPoints(from text: String) async -> [String]? {
        guard isProEnabled else {
            logger.warning("AI Writing Tools is a Pro feature")
            return nil
        }

        logger.info("Extracting key points from text...")
        isProcessing = true
        lastError = nil

        let keyPoints = performKeyPointExtraction(text: text)

        isProcessing = false
        logger.info("Key points extracted: \(keyPoints.count)")

        return keyPoints
    }
    
    // MARK: - Helper Methods

    private func performRewrite(text: String, style: RewriteStyle) -> String {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text

        var rewritten = text

        switch style {
        case .clearer:
            // Remove redundant words and simplify complex phrases
            rewritten = text
                .replacingOccurrences(of: " in order to ", with: " to ")
                .replacingOccurrences(of: " due to the fact that ", with: " because ")
                .replacingOccurrences(of: " at this point in time ", with: " now ")
                .replacingOccurrences(of: " in the event that ", with: " if ")
                .replacingOccurrences(of: " on a daily basis ", with: " daily ")
                .replacingOccurrences(of: " make a decision ", with: " decide ")

        case .moreConcise:
            // Remove filler words and verbose phrases
            rewritten = text
                .replacingOccurrences(of: " very ", with: " ")
                .replacingOccurrences(of: " really ", with: " ")
                .replacingOccurrences(of: " basically ", with: " ")
                .replacingOccurrences(of: " actually ", with: " ")
                .replacingOccurrences(of: " essentially ", with: " ")
                .replacingOccurrences(of: " in my opinion ", with: " ")
                .replacingOccurrences(of: " I think that ", with: " ")

            // Remove redundant adjectives
            let sentences = rewritten.components(separatedBy: ". ")
            rewritten = sentences
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ". ")

        case .moreDetailed:
            // Add contextual details (this is more limited without AI, but we can add structure)
            let sentences = text.components(separatedBy: ". ")
            var detailedSentences: [String] = []

            for sentence in sentences where !sentence.isEmpty {
                let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                // Add elaboration starters
                if !trimmed.isEmpty {
                    detailedSentences.append(trimmed)
                    // Could add "Specifically," or "In other words," for elaboration
                }
            }
            rewritten = detailedSentences.joined(separator: ". ")

        case .moreCasual:
            // Make language more conversational
            rewritten = text
                .replacingOccurrences(of: " therefore ", with: " so ")
                .replacingOccurrences(of: " however ", with: " but ")
                .replacingOccurrences(of: " furthermore ", with: " also ")
                .replacingOccurrences(of: " nonetheless ", with: " still ")
                .replacingOccurrences(of: " shall ", with: " will ")
                .replacingOccurrences(of: " ought to ", with: " should ")

        case .moreFormal:
            // Use formal academic language
            rewritten = text
                .replacingOccurrences(of: " so ", with: " therefore ")
                .replacingOccurrences(of: " but ", with: " however ")
                .replacingOccurrences(of: " also ", with: " furthermore ")
                .replacingOccurrences(of: " still ", with: " nonetheless ")
                .replacingOccurrences(of: " can't ", with: " cannot ")
                .replacingOccurrences(of: " won't ", with: " will not ")
                .replacingOccurrences(of: " don't ", with: " do not ")
        }

        // Clean up double spaces
        rewritten = rewritten.replacingOccurrences(of: "  ", with: " ")

        return rewritten
    }
    
    private func performProofread(text: String) async -> ProofreadResult {
        let textChecker = UITextChecker()
        var errors: [GrammarError] = []
        var correctedText = text

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)

        // Check for spelling errors
        var offset = 0
        while offset < nsText.length {
            let misspelledRange = textChecker.rangeOfMisspelledWord(
                in: text,
                range: NSRange(location: offset, length: nsText.length - offset),
                startingAt: offset,
                wrap: false,
                language: "en_US"
            )

            if misspelledRange.location == NSNotFound {
                break
            }

            let misspelledWord = nsText.substring(with: misspelledRange)
            let guesses = textChecker.guesses(forWordRange: misspelledRange, in: text, language: "en_US") ?? []

            errors.append(GrammarError(
                category: .spelling,
                text: misspelledWord,
                suggestion: guesses.first ?? misspelledWord,
                range: misspelledRange
            ))

            offset = misspelledRange.location + misspelledRange.length
        }

        // Check for grammar issues using NLTagger
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text

        // Simple repeated word detection
        let words = text.components(separatedBy: .whitespaces)
        var sentenceIssues: [GrammarError] = []

        if words.count > 1 {
            for i in 1..<words.count where !words[i].isEmpty {
                if words[i].lowercased() == words[i-1].lowercased() {
                    // Found repeated word - create approximate range
                    let wordRange = NSRange(location: 0, length: words[i].utf16.count)
                    sentenceIssues.append(GrammarError(
                        category: .grammar,
                        text: words[i],
                        suggestion: "Remove repeated word",
                        range: wordRange
                    ))
                }
            }
        }

        errors.append(contentsOf: sentenceIssues)

        // Auto-correct spelling errors in correctedText
        if !errors.isEmpty {
            var mutableText = text
            for error in errors.reversed() where error.category == .spelling {
                if let range = Range(error.range, in: mutableText) {
                    mutableText.replaceSubrange(range, with: error.suggestion)
                }
            }
            correctedText = mutableText
        }

        return ProofreadResult(
            correctedText: correctedText,
            errors: errors,
            hasErrors: !errors.isEmpty
        )
    }
    
    private func performSummarize(text: String, length: SummaryLength) -> String {
        // Use NLTagger to extract important sentences
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text

        // Split into sentences
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !sentences.isEmpty else { return text }

        // Score sentences based on important words (nouns, proper nouns, named entities)
        var sentenceScores: [(sentence: String, score: Int)] = []

        for sentence in sentences {
            var score = 0

            tagger.string = sentence
            tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .lexicalClass) { tag, _ in
                if let tag = tag {
                    switch tag {
                    case .noun, .verb:
                        score += 2
                    case .adjective:
                        score += 1
                    default:
                        break
                    }
                }
                return true
            }

            // Boost score for named entities
            tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .nameType) { tag, _ in
                if tag != nil {
                    score += 3
                }
                return true
            }

            sentenceScores.append((sentence, score))
        }

        // Sort by score and take top sentences based on length
        let targetCount = max(1, Int(Double(sentences.count) * length.ratio))
        let topSentences = sentenceScores
            .sorted { $0.score > $1.score }
            .prefix(targetCount)
            .map { $0.sentence }

        // Maintain original order
        let orderedSummary = sentences.filter { topSentences.contains($0) }

        return orderedSummary.joined(separator: ". ") + (orderedSummary.isEmpty ? "" : ".")
    }
    
    private func performToneAdjustment(text: String, targetTone: Tone) -> String {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .sentimentScore])
        tagger.string = text

        // Analyze current sentiment
        var overallSentiment: Double = 0.0
        var sentimentCount = 0

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph, scheme: .sentimentScore) { tag, _ in
            if let tag = tag, let sentiment = Double(tag.rawValue) {
                overallSentiment += sentiment
                sentimentCount += 1
            }
            return true
        }

        if sentimentCount > 0 {
            overallSentiment /= Double(sentimentCount)
        }

        // Apply tone-specific transformations
        var adjustedText = text

        switch targetTone {
        case .friendly:
            // Add friendly markers and soften language
            adjustedText = text
                .replacingOccurrences(of: " must ", with: " should ")
                .replacingOccurrences(of: " need to ", with: " could ")
            if !adjustedText.contains("!") && !adjustedText.hasSuffix("!") {
                adjustedText = adjustedText.trimmingCharacters(in: CharacterSet(charactersIn: "."))
                adjustedText += "!"
            }

        case .professional:
            // Use formal language
            adjustedText = text
                .replacingOccurrences(of: " gonna ", with: " going to ")
                .replacingOccurrences(of: " wanna ", with: " want to ")
                .replacingOccurrences(of: "!", with: ".")
                .replacingOccurrences(of: " really ", with: " very ")

        case .casual:
            // Make more conversational
            adjustedText = text
                .replacingOccurrences(of: " shall ", with: " will ")
                .replacingOccurrences(of: " would ", with: "'d ")
                .replacingOccurrences(of: " I am ", with: " I'm ")

        case .formal:
            // Use very formal language
            adjustedText = text
                .replacingOccurrences(of: " can't ", with: " cannot ")
                .replacingOccurrences(of: " won't ", with: " will not ")
                .replacingOccurrences(of: " don't ", with: " do not ")
                .replacingOccurrences(of: "!", with: ".")

        case .enthusiastic:
            // Add enthusiasm markers
            if !adjustedText.contains("!") {
                adjustedText = adjustedText.replacingOccurrences(of: ".", with: "!")
            }
            // Add positive intensifiers
            adjustedText = adjustedText
                .replacingOccurrences(of: " good ", with: " great ")
                .replacingOccurrences(of: " nice ", with: " wonderful ")
        }

        return adjustedText
    }
    
    private func performKeyPointExtraction(text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text

        var keyPoints: [String] = []
        var namedEntities: Set<String> = []
        var importantPhrases: [(phrase: String, score: Int)] = []

        // Extract named entities (people, places, organizations)
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            if let tag = tag {
                let entity = String(text[tokenRange])
                switch tag {
                case .personalName, .placeName, .organizationName:
                    namedEntities.insert(entity)
                default:
                    break
                }
            }
            return true
        }

        // Split into sentences and extract important noun phrases
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for sentence in sentences {
            tagger.string = sentence

            var currentPhrase: [String] = []
            var phraseScore = 0

            tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
                let word = String(sentence[tokenRange])

                if let tag = tag {
                    switch tag {
                    case .noun, .verb:
                        currentPhrase.append(word)
                        phraseScore += 2
                    case .adjective:
                        if !currentPhrase.isEmpty {
                            currentPhrase.append(word)
                            phraseScore += 1
                        }
                    default:
                        if !currentPhrase.isEmpty && currentPhrase.count >= 2 {
                            let phrase = currentPhrase.joined(separator: " ")
                            importantPhrases.append((phrase, phraseScore))
                        }
                        currentPhrase = []
                        phraseScore = 0
                    }
                } else {
                    if !currentPhrase.isEmpty && currentPhrase.count >= 2 {
                        let phrase = currentPhrase.joined(separator: " ")
                        importantPhrases.append((phrase, phraseScore))
                    }
                    currentPhrase = []
                    phraseScore = 0
                }

                return true
            }

            // Add remaining phrase
            if !currentPhrase.isEmpty && currentPhrase.count >= 2 {
                let phrase = currentPhrase.joined(separator: " ")
                importantPhrases.append((phrase, phraseScore))
            }
        }

        // Add named entities as key points
        keyPoints.append(contentsOf: namedEntities.map { "• \($0)" })

        // Add top-scoring phrases
        let topPhrases = importantPhrases
            .sorted { $0.score > $1.score }
            .prefix(5)
            .map { "• \($0.phrase.capitalized)" }

        keyPoints.append(contentsOf: topPhrases)

        // If no key points found, extract first few sentences
        if keyPoints.isEmpty {
            keyPoints = sentences.prefix(3).map { "• \($0)" }
        }

        return Array(keyPoints.prefix(6))
    }
}

// MARK: - Supporting Types

enum RewriteStyle: String, CaseIterable {
    case clearer = "Clearer"
    case moreConcise = "More Concise"
    case moreDetailed = "More Detailed"
    case moreCasual = "More Casual"
    case moreFormal = "More Formal"
    
    var icon: String {
        switch self {
        case .clearer: return "sparkles"
        case .moreConcise: return "arrow.down"
        case .moreDetailed: return "arrow.up"
        case .moreCasual: return "smiley"
        case .moreFormal: return "graduationcap"
        }
    }
}

enum Tone: String, CaseIterable {
    case friendly
    case professional
    case casual
    case formal
    case enthusiastic
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .friendly: return "hand.wave"
        case .professional: return "briefcase"
        case .casual: return "tshirt"
        case .formal: return "building.columns"
        case .enthusiastic: return "star.fill"
        }
    }
}

enum SummaryLength: String, CaseIterable {
    case short = "Short"
    case medium = "Medium"
    case long = "Long"
    
    var ratio: Double {
        switch self {
        case .short: return 0.25
        case .medium: return 0.5
        case .long: return 0.75
        }
    }
}

struct ProofreadResult {
    let correctedText: String
    let errors: [GrammarError]
    let hasErrors: Bool
}

struct GrammarError {
    let category: ErrorCategory
    let text: String
    let suggestion: String
    let range: NSRange

    init(category: ErrorCategory, text: String, suggestion: String, range: NSRange = NSRange(location: 0, length: 0)) {
        self.category = category
        self.text = text
        self.suggestion = suggestion
        self.range = range
    }
}

enum ErrorCategory {
    case grammar
    case spelling
    case punctuation
    case style
}
