import Foundation
import os

nonisolated enum SecureVoiceFileStore {
    private static let logger = Logger(subsystem: "a-do", category: "VoiceFiles")
    private static let directoryName = "VoiceReminders"

    static func sanitizedFileName(_ fileName: String) -> String {
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

    static func fileURL(fileName: String) -> URL? {
        do {
            let directory = try protectedDirectory()
            return directory.appendingPathComponent(sanitizedFileName(fileName), isDirectory: false)
        } catch {
            logger.error("Failed to resolve secure voice file directory: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func makeNewFileURL() -> URL? {
        fileURL(fileName: "voice_reminder_\(UUID().uuidString).m4a")
    }

    @discardableResult
    static func applyProtectedAttributesIfPossible(to url: URL) -> Bool {
        do {
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
            return true
        } catch {
            logger.error("Failed to apply protected file attributes: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private static func protectedDirectory() throws -> URL {
        let fileManager = FileManager.default
        guard let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let directoryURL = baseDirectory.appendingPathComponent(directoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableDirectoryURL = directoryURL
        try mutableDirectoryURL.setResourceValues(resourceValues)

        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: directoryURL.path
        )

        return directoryURL
    }
}
