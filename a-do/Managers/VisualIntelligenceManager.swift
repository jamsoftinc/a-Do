//
//  VisualIntelligenceManager.swift
//  a-do
//
//  Visual Intelligence for iOS 26 - Camera scanning for documents and notes
//

import Foundation
import Vision
import VisionKit
import Observation
import os

@MainActor
@Observable
final class VisualIntelligenceManager {
    static let shared = VisualIntelligenceManager()
    
    private let logger = Logger(subsystem: "a-do", category: "VisualIntelligence")
    
    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.canUseVisualIntelligence
    }
    
    var isProcessing: Bool = false
    var scannedText: String = ""
    var lastError: String?
    
    private init() {}
    
    // MARK: - Document Scanning
    
    func scanDocument(from image: UIImage) async -> String? {
        guard isProEnabled else {
            logger.warning("Visual Intelligence is a Pro feature")
            return nil
        }
        
        logger.info("Scanning document for text...")
        isProcessing = true
        lastError = nil
        
        // Create Vision request for text recognition
        guard let cgImage = image.cgImage else {
            lastError = "Invalid image"
            isProcessing = false
            return nil
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                Task { @MainActor in
                    self.lastError = error.localizedDescription
                    self.isProcessing = false
                }
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                Task { @MainActor in
                    self.isProcessing = false
                }
                return
            }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            Task { @MainActor in
                self.scannedText = recognizedStrings.joined(separator: "\n")
                self.isProcessing = false
                self.logger.info("Text scanned successfully: \(self.scannedText.count) characters")
            }
        }
        
        // Request specific text recognition configuration
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
            return scannedText
        } catch {
            lastError = error.localizedDescription
            isProcessing = false
            logger.error("Failed to scan document: \(error.localizedDescription)")
            return nil
        }
    }
    
    func extractReminders(from text: String) async -> [ParsedReminder] {
        guard isProEnabled else {
            logger.warning("Visual Intelligence is a Pro feature")
            return []
        }
        
        logger.info("Extracting reminders from scanned text...")
        
        let lines = text.components(separatedBy: .newlines)
        var reminders: [ParsedReminder] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !trimmedLine.isEmpty else { continue }
            
            // Skip if it looks like a header or title
            if trimmedLine.count < 3 || (trimmedLine.count < 50 && trimmedLine.allSatisfy { $0.isUppercase }) {
                continue
            }
            
            // Use NLP to parse the line into a reminder
            let parsed = await NaturalLanguageProcessor.shared.parseReminderText(trimmedLine)
            
            if !parsed.finalText.isEmpty {
                reminders.append(parsed)
            }
        }
        
        logger.info("Extracted \(reminders.count) reminders from scanned text")
        
        return reminders
    }
    
    func scanBusinessCard(from image: UIImage) async -> BusinessCard? {
        guard isProEnabled else {
            logger.warning("Visual Intelligence is a Pro feature")
            return nil
        }
        
        logger.info("Scanning business card...")
        isProcessing = true
        
        // Scan for text
        guard let text = await scanDocument(from: image) else {
            isProcessing = false
            return nil
        }
        
        // Extract contact information
        let contactInfo = extractContactInfo(from: text)
        
        isProcessing = false
        logger.info("Business card scanned successfully")
        
        return BusinessCard(
            name: contactInfo.name,
            company: contactInfo.company,
            email: contactInfo.email,
            phone: contactInfo.phone,
            website: contactInfo.website
        )
    }
    
    // MARK: - Helper Methods
    
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
            let phonePattern = #"[\d\s\-\(\)]{10,}"#
            if let phoneRange = trimmed.range(of: phonePattern, options: .regularExpression) {
                let potentialPhone = String(trimmed[phoneRange])
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                
                if potentialPhone.count >= 10 {
                    phone = potentialPhone
                }
            }
            
            // Website detection
            if trimmed.contains("www.") || trimmed.contains(".com") || trimmed.contains(".net") || trimmed.contains(".org") {
                website = trimmed
            }
            
            // Name (usually first line)
            if index == 0 && name.isEmpty {
                name = trimmed
            }
            
            // Company (usually second line, and could contain common words)
            if index == 1 && company.isEmpty && !trimmed.isEmpty {
                company = trimmed
            }
        }
        
        return (name, company, email, phone, website)
    }
}

// MARK: - Supporting Types

struct BusinessCard {
    let name: String
    let company: String
    let email: String
    let phone: String
    let website: String
    
    func createReminder() -> String {
        var reminderText = "Follow up with \(name)"
        
        if !company.isEmpty {
            reminderText += " from \(company)"
        }
        
        if !email.isEmpty {
            reminderText += " (\(email))"
        }
        
        return reminderText
    }
}
