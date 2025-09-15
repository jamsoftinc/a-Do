//
//  SecurityUtils.swift
//  a-do
//
//  Security utilities for input validation and sanitization
//

import Foundation
import CryptoKit
import UIKit
import os

/// Security utilities for input validation, sanitization, and secure operations
struct SecurityUtils {
    
    // MARK: - Input Validation
    
    /// Validates and sanitizes text input to prevent injection attacks
    /// - Parameter input: The input string to validate
    /// - Returns: Sanitized string or nil if invalid
    static func sanitizeTextInput(_ input: String?) -> String? {
        guard let input = input else { return nil }
        
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for empty input
        guard !trimmed.isEmpty else { return nil }
        
        // Check for reasonable length limits
        guard trimmed.count <= 10000 else { return nil }
        
        // Remove potentially dangerous characters
        let sanitized = trimmed
            .replacingOccurrences(of: "<script", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "javascript:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "data:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "vbscript:", with: "", options: .caseInsensitive)
        
        return sanitized
    }
    
    /// Validates email format
    /// - Parameter email: Email string to validate
    /// - Returns: True if email format is valid
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    /// Validates URL format and ensures it's safe
    /// - Parameter urlString: URL string to validate
    /// - Returns: True if URL is valid and safe
    static func isValidAndSafeURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        // Only allow HTTP and HTTPS schemes
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else { return false }
        
        // Prevent localhost and private IP ranges in production
        if let host = url.host?.lowercased() {
            let dangerousHosts = ["localhost", "127.0.0.1", "0.0.0.0"]
            if dangerousHosts.contains(host) { return false }
            
            // Check for private IP ranges
            if host.hasPrefix("192.168.") || host.hasPrefix("10.") || host.hasPrefix("172.") {
                return false
            }
        }
        
        return true
    }
    
    /// Validates hex color format
    /// - Parameter hex: Hex color string
    /// - Returns: Validated hex color or default
    static func validateHexColor(_ hex: String) -> String {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let hexPattern = "^#?([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$"
        let hexPredicate = NSPredicate(format: "SELF MATCHES %@", hexPattern)
        
        if hexPredicate.evaluate(with: sanitized) {
            return sanitized.hasPrefix("#") ? sanitized : "#" + sanitized
        }
        
        return "#007AFF" // Default blue color
    }
    
    // MARK: - User ID Validation
    
    /// Gets the current user ID securely
    /// - Returns: Current user ID or fallback identifier
    static func getCurrentUserID() -> String {
        // Use CloudKit user record ID for secure user identification
        // This prevents hardcoded user IDs and ensures proper authentication
        if let userRecordID = CollaborationManager.shared.currentUserRecordID {
            return userRecordID
        }
        
        // Fallback to device-specific identifier (not recommended for production)
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown-user"
    }
    
    /// Validates user ID format to prevent injection
    /// - Parameter userID: User ID to validate
    /// - Returns: True if user ID format is valid
    static func isValidUserID(_ userID: String) -> Bool {
        // User IDs should be UUIDs or CloudKit record IDs
        let trimmed = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for UUID format
        if UUID(uuidString: trimmed) != nil {
            return true
        }
        
        // Check for CloudKit record ID format (alphanumeric with hyphens and underscores)
        let cloudKitPattern = "^[A-Za-z0-9_-]+$"
        let cloudKitPredicate = NSPredicate(format: "SELF MATCHES %@", cloudKitPattern)
        return cloudKitPredicate.evaluate(with: trimmed) && trimmed.count <= 255
    }
    
    // MARK: - Data Sanitization
    
    /// Sanitizes file names to prevent path traversal attacks
    /// - Parameter fileName: File name to sanitize
    /// - Returns: Safe file name
    static func sanitizeFileName(_ fileName: String) -> String {
        let sanitized = fileName
            .replacingOccurrences(of: "..", with: "")
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "\\", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "|", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return sanitized.isEmpty ? "untitled" : sanitized
    }
    
    // MARK: - Secure Random Generation
    
    /// Generates a cryptographically secure random string
    /// - Parameter length: Length of the random string
    /// - Returns: Secure random string
    static func generateSecureRandomString(length: Int = 32) -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        var result = ""
        
        for _ in 0..<length {
            let randomIndex = Int.random(in: 0..<characters.count)
            let character = characters[characters.index(characters.startIndex, offsetBy: randomIndex)]
            result.append(character)
        }
        
        return result
    }
    
    // MARK: - Rate Limiting
    
    private static var rateLimitStore: [String: (count: Int, lastReset: Date)] = [:]
    private static let rateLimitQueue = DispatchQueue(label: "rate-limit", attributes: .concurrent)
    
    /// Checks if an operation is within rate limits
    /// - Parameters:
    ///   - key: Unique key for the operation
    ///   - maxAttempts: Maximum attempts allowed
    ///   - timeWindow: Time window in seconds
    /// - Returns: True if within rate limits
    static func isWithinRateLimit(key: String, maxAttempts: Int = 10, timeWindow: TimeInterval = 60) -> Bool {
        return rateLimitQueue.sync {
            let now = Date()
            
            if let existing = rateLimitStore[key] {
                // Reset counter if time window has passed
                if now.timeIntervalSince(existing.lastReset) > timeWindow {
                    rateLimitStore[key] = (count: 1, lastReset: now)
                    return true
                }
                
                // Check if within limits
                if existing.count >= maxAttempts {
                    return false
                }
                
                // Increment counter
                rateLimitStore[key] = (count: existing.count + 1, lastReset: existing.lastReset)
                return true
            } else {
                // First attempt
                rateLimitStore[key] = (count: 1, lastReset: now)
                return true
            }
        }
    }
    
    // MARK: - Secure Comparison
    
    /// Performs constant-time string comparison to prevent timing attacks
    /// - Parameters:
    ///   - string1: First string
    ///   - string2: Second string
    /// - Returns: True if strings are equal
    static func secureStringCompare(_ string1: String, _ string2: String) -> Bool {
        let data1 = Data(string1.utf8)
        let data2 = Data(string2.utf8)
        
        guard data1.count == data2.count else { return false }
        
        var result = 0
        for i in 0..<data1.count {
            result |= Int(data1[i] ^ data2[i])
        }
        
        return result == 0
    }
    
    // MARK: - Secure Error Handling
    
    /// Sanitizes error messages to prevent information disclosure
    /// - Parameter error: The error to sanitize
    /// - Returns: Safe error message for logging/display
    static func sanitizeErrorMessage(_ error: Error) -> String {
        let errorString = error.localizedDescription
        
        // Remove potentially sensitive information
        let sanitized = errorString
            .replacingOccurrences(of: "password", with: "[REDACTED]", options: .caseInsensitive)
            .replacingOccurrences(of: "token", with: "[REDACTED]", options: .caseInsensitive)
            .replacingOccurrences(of: "key", with: "[REDACTED]", options: .caseInsensitive)
            .replacingOccurrences(of: "secret", with: "[REDACTED]", options: .caseInsensitive)
        
        // Limit error message length
        return sanitized.securelyTruncated(to: 500)
    }
    
    /// Logs errors securely without exposing sensitive information
    /// - Parameters:
    ///   - error: The error to log
    ///   - context: Additional context for the error
    ///   - logger: The logger to use
    static func logSecureError(_ error: Error, context: String, logger: Logger) {
        let sanitizedMessage = sanitizeErrorMessage(error)
        logger.error("[\(context)] \(sanitizedMessage)")
    }
}

// MARK: - Secure Logging Extension

extension Logger {
    /// Logs messages with automatic sanitization
    /// - Parameters:
    ///   - message: Message to log
    ///   - sanitize: Whether to sanitize the message (default: true)
    func secureInfo(_ message: String, sanitize: Bool = true) {
        if sanitize {
            let sanitized = SecurityUtils.sanitizeTextInput(message) ?? "[INVALID_INPUT]"
            self.info("\(sanitized)")
        } else {
            self.info("\(message)")
        }
    }
    
    /// Logs warnings with automatic sanitization
    /// - Parameters:
    ///   - message: Message to log
    ///   - sanitize: Whether to sanitize the message (default: true)
    func secureWarning(_ message: String, sanitize: Bool = true) {
        if sanitize {
            let sanitized = SecurityUtils.sanitizeTextInput(message) ?? "[INVALID_INPUT]"
            self.warning("\(sanitized)")
        } else {
            self.warning("\(message)")
        }
    }
}

// MARK: - String Extension for Security

extension String {
    /// Safely truncates string to maximum length
    /// - Parameter maxLength: Maximum allowed length
    /// - Returns: Truncated string
    func securelyTruncated(to maxLength: Int) -> String {
        guard self.count > maxLength else { return self }
        let endIndex = self.index(self.startIndex, offsetBy: maxLength)
        return String(self[..<endIndex])
    }
    
    /// Checks if string contains only safe characters
    var containsOnlySafeCharacters: Bool {
        let allowedCharacterSet = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(.punctuationCharacters)
            .subtracting(CharacterSet(charactersIn: "<>\"'&"))
        
        return self.unicodeScalars.allSatisfy { allowedCharacterSet.contains($0) }
    }
}
