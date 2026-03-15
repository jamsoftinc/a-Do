//
//  VisualIntelligenceManager.swift
//  a-do
//
//  Visual Intelligence integration
//  Includes document scanning, OCR, and Visual Intelligence framework support
//
//  Requires: iOS 26+
//

import Foundation
import Vision
import VisionKit
import Observation
import os
import UIKit
import SwiftData

// MARK: - Business Card Model

struct BusinessCard: Sendable {
    let name: String
    let company: String
    let email: String
    let phone: String
    let website: String

    var isEmpty: Bool {
        name.isEmpty && company.isEmpty && email.isEmpty && phone.isEmpty && website.isEmpty
    }

    var contactSummary: String {
        var parts: [String] = []
        if !name.isEmpty { parts.append(name) }
        if !company.isEmpty { parts.append(company) }
        return parts.joined(separator: " - ")
    }

    var formattedDetails: String {
        var lines: [String] = []
        if !email.isEmpty { lines.append("Email: \(email)") }
        if !phone.isEmpty { lines.append("Phone: \(phone)") }
        if !website.isEmpty { lines.append("Website: \(website)") }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Scanned Item Types

enum ScannedItemType: String, CaseIterable {
    case text
    case businessCard
    case document
    case handwriting
    case barcode
    case qrCode

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .businessCard: return "Business Card"
        case .document: return "Document"
        case .handwriting: return "Handwriting"
        case .barcode: return "Barcode"
        case .qrCode: return "QR Code"
        }
    }

    var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .businessCard: return "person.crop.rectangle"
        case .document: return "doc.text"
        case .handwriting: return "pencil.and.scribble"
        case .barcode: return "barcode"
        case .qrCode: return "qrcode"
        }
    }
}

// MARK: - Scan Result

struct ScanResult {
    let type: ScannedItemType
    let text: String
    let confidence: Double
    let boundingBox: CGRect?
    let metadata: [String: Any]

    init(type: ScannedItemType, text: String, confidence: Double = 1.0, boundingBox: CGRect? = nil, metadata: [String: Any] = [:]) {
        self.type = type
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.metadata = metadata
    }
}

// MARK: - Visual Intelligence Manager

@MainActor
@Observable
final class VisualIntelligenceManager {
    static let shared = VisualIntelligenceManager()

    private let logger = Logger(subsystem: "a-do", category: "VisualIntelligence")

    // State
    var isProcessing: Bool = false
    var scannedText: String = ""
    var lastError: String?
    var lastScanResults: [ScanResult] = []

    // Scanner availability
    var isScannerAvailable: Bool {
        VNDocumentCameraViewController.isSupported
    }

    private init() {}

    // MARK: - Pro Feature Check

    var isProEnabled: Bool {
        return EntitlementManager.shared.isProUser
    }

    private func requirePro() -> Bool {
        guard isProEnabled else {
            logger.warning("Visual Intelligence is a Pro feature")
            lastError = "Pro subscription required"
            return false
        }
        return true
    }

    // MARK: - Document Scanning with OCR

    /// Scan text from an image using Vision framework
    func scanDocument(from image: UIImage) async -> String? {
        guard requirePro() else { return nil }

        logger.info("Scanning document for text...")
        isProcessing = true
        lastError = nil
        lastScanResults = []

        defer { isProcessing = false }

        guard let cgImage = image.cgImage else {
            lastError = "Invalid image"
            return nil
        }

        return await withCheckedContinuation { continuation in
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            let request = VNRecognizeTextRequest { [weak self] request, error in
                Task { @MainActor in
                    if let error = error {
                        self?.lastError = error.localizedDescription
                        continuation.resume(returning: nil)
                        return
                    }

                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: nil)
                        return
                    }

                    var results: [ScanResult] = []
                    var fullText: [String] = []

                    for observation in observations {
                        if let topCandidate = observation.topCandidates(1).first {
                            fullText.append(topCandidate.string)
                            results.append(ScanResult(
                                type: .text,
                                text: topCandidate.string,
                                confidence: Double(topCandidate.confidence),
                                boundingBox: observation.boundingBox
                            ))
                        }
                    }

                    let scannedText = fullText.joined(separator: "\n")
                    self?.scannedText = scannedText
                    self?.lastScanResults = results
                    self?.logger.info("Text scanned successfully: \(scannedText.count) characters")

                    continuation.resume(returning: scannedText)
                }
            }

            // Configure for accurate recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            do {
                try requestHandler.perform([request])
            } catch {
                lastError = error.localizedDescription
                logger.error("Failed to scan document: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Handwriting Recognition

    /// Specifically recognize handwritten text
    func recognizeHandwriting(from image: UIImage) async -> String? {
        guard requirePro() else { return nil }

        logger.info("Recognizing handwriting...")
        isProcessing = true
        lastError = nil

        defer { isProcessing = false }

        guard let cgImage = image.cgImage else {
            lastError = "Invalid image"
            return nil
        }

        return await withCheckedContinuation { continuation in
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            let request = VNRecognizeTextRequest { [weak self] request, error in
                Task { @MainActor in
                    if let error = error {
                        self?.lastError = error.localizedDescription
                        continuation.resume(returning: nil)
                        return
                    }

                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let recognizedStrings = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }

                    let text = recognizedStrings.joined(separator: "\n")
                    self?.scannedText = text
                    self?.lastScanResults = [ScanResult(type: .handwriting, text: text)]
                    self?.logger.info("Handwriting recognized: \(text.count) characters")

                    continuation.resume(returning: text)
                }
            }

            // Optimize for handwriting
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.revision = VNRecognizeTextRequestRevision3

            do {
                try requestHandler.perform([request])
            } catch {
                lastError = error.localizedDescription
                logger.error("Failed to recognize handwriting: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Business Card Scanning

    /// Scan a business card and extract contact information
    func scanBusinessCard(from image: UIImage) async -> BusinessCard? {
        guard requirePro() else { return nil }

        logger.info("Scanning business card...")
        isProcessing = true

        defer { isProcessing = false }

        // First, scan the text
        guard let text = await scanDocument(from: image) else {
            return nil
        }

        // Extract contact information
        let contactInfo = extractContactInfo(from: text)

        let card = BusinessCard(
            name: contactInfo.name,
            company: contactInfo.company,
            email: contactInfo.email,
            phone: contactInfo.phone,
            website: contactInfo.website
        )

        lastScanResults = [ScanResult(
            type: .businessCard,
            text: text,
            metadata: [
                "name": contactInfo.name,
                "company": contactInfo.company,
                "email": contactInfo.email,
                "phone": contactInfo.phone,
                "website": contactInfo.website
            ]
        )]

        logger.info("Business card scanned: \(contactInfo.name)")
        return card
    }

    private func extractContactInfo(from text: String) -> (name: String, company: String, email: String, phone: String, website: String) {
        var name = ""
        var company = ""
        var email = ""
        var phone = ""
        var website = ""

        let lines = text.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Email detection
            if trimmed.contains("@") {
                let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
                if let emailRange = trimmed.range(of: emailPattern, options: .regularExpression) {
                    email = String(trimmed[emailRange])
                }
            }

            // Phone detection
            let phonePattern = #"[\d\s\-\(\)\.]{10,}"#
            if let phoneRange = trimmed.range(of: phonePattern, options: .regularExpression) {
                let potentialPhone = String(trimmed[phoneRange])
                    .components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .joined()

                if potentialPhone.count >= 10 && phone.isEmpty {
                    phone = potentialPhone
                }
            }

            // Website detection
            let webPatterns = ["www.", "http://", "https://", ".com", ".net", ".org", ".io"]
            for pattern in webPatterns {
                if trimmed.lowercased().contains(pattern) && website.isEmpty {
                    website = trimmed
                    break
                }
            }

            // Name (usually first non-empty line without email/phone/website)
            if index == 0 && name.isEmpty && !trimmed.contains("@") {
                let hasDigits = trimmed.rangeOfCharacter(from: .decimalDigits) != nil
                if !hasDigits && trimmed.count > 2 && trimmed.count < 50 {
                    name = trimmed
                }
            }

            // Company (often second line or contains keywords)
            let companyKeywords = ["inc", "llc", "ltd", "corp", "company", "group", "solutions", "consulting"]
            let lowerTrimmed = trimmed.lowercased()
            if companyKeywords.contains(where: { lowerTrimmed.contains($0) }) && company.isEmpty {
                company = trimmed
            } else if index == 1 && company.isEmpty && !trimmed.contains("@") {
                let hasDigits = trimmed.rangeOfCharacter(from: .decimalDigits) != nil
                if !hasDigits && trimmed.count > 2 {
                    company = trimmed
                }
            }
        }

        return (name, company, email, phone, website)
    }

    // MARK: - QR Code and Barcode Scanning

    /// Scan QR codes and barcodes
    func scanBarcodes(from image: UIImage) async -> [ScanResult] {
        guard requirePro() else { return [] }

        logger.info("Scanning for barcodes...")
        isProcessing = true
        lastError = nil

        defer { isProcessing = false }

        guard let cgImage = image.cgImage else {
            lastError = "Invalid image"
            return []
        }

        return await withCheckedContinuation { continuation in
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            let request = VNDetectBarcodesRequest { [weak self] request, error in
                Task { @MainActor in
                    if let error = error {
                        self?.lastError = error.localizedDescription
                        continuation.resume(returning: [])
                        return
                    }

                    guard let observations = request.results as? [VNBarcodeObservation] else {
                        continuation.resume(returning: [])
                        return
                    }

                    var results: [ScanResult] = []

                    for observation in observations {
                        let type: ScannedItemType = observation.symbology == .qr ? .qrCode : .barcode
                        let payload = observation.payloadStringValue ?? ""

                        results.append(ScanResult(
                            type: type,
                            text: payload,
                            confidence: Double(observation.confidence),
                            boundingBox: observation.boundingBox,
                            metadata: ["symbology": observation.symbology.rawValue]
                        ))
                    }

                    self?.lastScanResults = results
                    self?.logger.info("Found \(results.count) barcodes")

                    continuation.resume(returning: results)
                }
            }

            do {
                try requestHandler.perform([request])
            } catch {
                lastError = error.localizedDescription
                logger.error("Failed to scan barcodes: \(error.localizedDescription)")
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - Extract Reminders from Text

    /// Parse scanned text and extract potential reminders
    func extractReminders(from text: String) async -> [ParsedReminder] {
        guard requirePro() else { return [] }

        logger.info("Extracting reminders from scanned text...")

        let lines = text.components(separatedBy: .newlines)
        var reminders: [ParsedReminder] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedLine.isEmpty else { continue }

            // Skip headers and short lines
            if trimmedLine.count < 3 {
                continue
            }

            // Skip if looks like a header (all caps, short)
            if trimmedLine.count < 30 && trimmedLine == trimmedLine.uppercased() {
                continue
            }

            // Use NLP to parse the line
            let parsed = await NaturalLanguageProcessor.shared.parseReminderText(trimmedLine)

            if !parsed.finalText.isEmpty && parsed.finalText.count >= 3 {
                reminders.append(parsed)
            }
        }

        logger.info("Extracted \(reminders.count) reminders from scanned text")
        return reminders
    }

    // MARK: - Document Analysis

    /// Analyze a document image to detect its type
    func analyzeDocument(from image: UIImage) async -> ScannedItemType {
        guard requirePro() else { return .document }

        logger.info("Analyzing document type...")

        guard let cgImage = image.cgImage else {
            return .document
        }

        // Check for barcodes first
        let barcodes = await scanBarcodes(from: image)
        if !barcodes.isEmpty {
            if barcodes.contains(where: { $0.type == .qrCode }) {
                return .qrCode
            }
            return .barcode
        }

        // Use text recognition to analyze content
        guard let text = await scanDocument(from: image) else {
            return .document
        }

        // Check if it's a business card (contains contact info patterns)
        let contactInfo = extractContactInfo(from: text)
        if !contactInfo.email.isEmpty || !contactInfo.phone.isEmpty {
            if text.components(separatedBy: .newlines).count < 15 {
                return .businessCard
            }
        }

        // Check for handwriting characteristics
        // (simplified - real implementation would use ML model)
        let lineCount = text.components(separatedBy: .newlines).count
        let averageLineLength = text.count / max(lineCount, 1)
        if averageLineLength < 30 && lineCount < 20 {
            return .handwriting
        }

        return .document
    }

    // MARK: - Live Text Integration

    /// Check if Live Text is available
    var isLiveTextAvailable: Bool {
        return ImageAnalyzer.isSupported
    }

    /// Analyze image using Live Text
    func analyzeWithLiveText(_ image: UIImage) async -> String? {
        guard requirePro() else { return nil }
        guard isLiveTextAvailable else { return nil }

        logger.info("Analyzing with Live Text...")
        isProcessing = true

        defer { isProcessing = false }

        let analyzer = ImageAnalyzer()
        let configuration = ImageAnalyzer.Configuration([.text])

        do {
            let analysis = try await analyzer.analyze(image, configuration: configuration)
            let transcript = analysis.transcript

            scannedText = transcript
            lastScanResults = [ScanResult(type: .text, text: transcript)]
            logger.info("Live Text analysis complete: \(transcript.count) characters")

            return transcript
        } catch {
            lastError = error.localizedDescription
            logger.error("Live Text analysis failed: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Visual Intelligence Extensions

extension VisualIntelligenceManager {

    /// Create a reminder from scanned content
    func createReminderFromScan(
        _ result: ScanResult,
        context: inout ModelContext
    ) async -> Reminder? {
        let parsed = await NaturalLanguageProcessor.shared.parseReminderText(result.text)
        let request = ReminderCreationService.Request(
            title: parsed.finalText,
            details: nil,
            dueDate: parsed.dueDate,
            priority: parsed.priority,
            useNaturalLanguageParsing: false
        )

        do {
            let reminder = try await ReminderCreationService.shared.createReminder(request: request, in: context)
            logger.info("Created reminder from scan: \(parsed.finalText)")
            return reminder
        } catch {
            logger.error("Failed to create reminder from scan: \(error.localizedDescription)")
            return nil
        }
    }

    /// Create a follow-up reminder from a business card
    func createFollowUpReminder(
        from card: BusinessCard,
        context: inout ModelContext
    ) async -> Reminder? {
        let title = "Follow up with \(card.name.isEmpty ? "contact" : card.name)"
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        let request = ReminderCreationService.Request(
            title: title,
            details: card.formattedDetails,
            dueDate: tomorrow,
            priority: .medium,
            useNaturalLanguageParsing: false
        )

        do {
            let reminder = try await ReminderCreationService.shared.createReminder(request: request, in: context)
            logger.info("Created follow-up reminder for: \(card.name)")
            return reminder
        } catch {
            logger.error("Failed to create follow-up reminder: \(error.localizedDescription)")
            return nil
        }
    }
}
