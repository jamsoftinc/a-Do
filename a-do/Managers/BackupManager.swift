//
//  BackupManager.swift
//  a-do
//
//  Enhanced backup and export manager
//

import Foundation
import SwiftData
import Observation
import os
import UniformTypeIdentifiers
import CryptoKit

@MainActor
@Observable
final class BackupManager {
    static let shared = BackupManager()
    
    private let logger = Logger(subsystem: "a-do", category: "Backup")
    
    // Processing state
    var isBackingUp: Bool = false
    var isRestoring: Bool = false
    var isExporting: Bool = false
    var isImporting: Bool = false
    var currentProgress: Double = 0.0
    var currentOperation: String = ""
    
    // Configuration
    private var configuration: BackupConfiguration?
    
    private init() {
        setupPeriodicBackup()
    }
    
    // MARK: - Configuration Management
    
    func getConfiguration(userId: String, context: ModelContext) -> BackupConfiguration {
        if let config = configuration, config.userId == userId {
            return config
        }
        
        let descriptor = FetchDescriptor<BackupConfiguration>(
            predicate: #Predicate { $0.userId == userId }
        )
        
        if let existingConfig = try? context.fetch(descriptor).first {
            configuration = existingConfig
            return existingConfig
        }
        
        // Create default configuration
        let newConfig = BackupConfiguration(userId: userId)
        context.insert(newConfig)
        
        do {
            try context.save()
            configuration = newConfig
            logger.info("Created backup configuration for user: \(userId)")
        } catch {
            logger.error("Failed to create backup configuration: \(error.localizedDescription)")
        }
        
        return newConfig
    }
    
    // MARK: - Backup Operations
    
    func createBackup(
        userId: String,
        type: BackupType = .full,
        format: BackupFormat = .json,
        context: ModelContext
    ) async -> BackupRecord? {
        guard !isBackingUp else {
            logger.warning("Backup already in progress")
            return nil
        }
        
        isBackingUp = true
        currentProgress = 0.0
        currentOperation = "Preparing backup..."
        
        defer {
            isBackingUp = false
            currentProgress = 0.0
            currentOperation = ""
        }
        
        let config = getConfiguration(userId: userId, context: context)
        let fileName = generateBackupFileName(type: type, format: format)
        let backupRecord = BackupRecord(userId: userId, fileName: fileName, backupType: type)
        backupRecord.format = format
        backupRecord.isCompressed = config.compressionEnabled
        backupRecord.isEncrypted = config.encryptionEnabled
        
        context.insert(backupRecord)
        
        do {
            try context.save()
            logger.info("Started backup: \(fileName)")
            
            // Collect data based on configuration
            currentOperation = "Collecting data..."
            currentProgress = 0.1
            
            let backupData = await collectBackupData(config: config, context: context)
            
            currentOperation = "Generating backup file..."
            currentProgress = 0.5
            
            // Generate backup content
            let backupContent = try generateBackupContent(data: backupData, format: format)
            
            currentOperation = "Processing backup..."
            currentProgress = 0.7
            
            // Apply compression if enabled
            var finalContent = backupContent
            if config.compressionEnabled {
                finalContent = try compressData(backupContent)
                backupRecord.isCompressed = true
            }
            
            // Apply encryption if enabled
            if config.encryptionEnabled {
                finalContent = try encryptData(finalContent, userId: userId)
                backupRecord.isEncrypted = true
            }
            
            currentOperation = "Saving backup..."
            currentProgress = 0.9
            
            // Save to file
            let fileURL = try saveBackupToFile(content: finalContent, fileName: fileName)
            backupRecord.filePath = fileURL.path
            
            // Calculate checksum
            let checksum = calculateChecksum(data: finalContent)
            
            // Update backup record
            backupRecord.markAsCompleted(fileSize: Int64(finalContent.count), checksum: checksum)
            backupRecord.reminderCount = backupData.reminders.count
            backupRecord.habitCount = backupData.habits.count
            backupRecord.timeEntryCount = backupData.timeEntries.count
            backupRecord.focusSessionCount = backupData.focusSessions.count
            
            // Update configuration
            config.lastBackupDate = Date()
            config.calculateNextBackupDate()
            
            try context.save()
            
            currentProgress = 1.0
            logger.info("Backup completed successfully: \(fileName)")
            
            // Clean up old backups if needed
            await cleanupOldBackups(userId: userId, maxBackups: config.maxBackupsToKeep, context: context)
            
            return backupRecord
            
        } catch {
            backupRecord.markAsFailed(error: error.localizedDescription)
            try? context.save()
            logger.error("Backup failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    func restoreBackup(_ backupRecord: BackupRecord, context: ModelContext) async -> Bool {
        guard !isRestoring else {
            logger.warning("Restore already in progress")
            return false
        }
        
        isRestoring = true
        currentProgress = 0.0
        currentOperation = "Preparing restore..."
        
        defer {
            isRestoring = false
            currentProgress = 0.0
            currentOperation = ""
        }
        
        do {
            currentOperation = "Reading backup file..."
            currentProgress = 0.1
            
            let fileURL = URL(fileURLWithPath: backupRecord.filePath)
            var backupData = try Data(contentsOf: fileURL)
            
            currentOperation = "Processing backup data..."
            currentProgress = 0.3
            
            // Decrypt if needed
            if backupRecord.isEncrypted {
                backupData = try decryptData(backupData, userId: backupRecord.userId)
            }
            
            // Decompress if needed
            if backupRecord.isCompressed {
                backupData = try decompressData(backupData)
            }
            
            currentOperation = "Parsing backup content..."
            currentProgress = 0.5
            
            // Parse backup content
            let parsedData = try parseBackupContent(data: backupData, format: backupRecord.format)
            
            currentOperation = "Restoring data..."
            currentProgress = 0.7
            
            // Restore data to context
            await restoreDataToContext(parsedData: parsedData, context: context)
            
            currentOperation = "Finalizing restore..."
            currentProgress = 0.9
            
            try context.save()
            
            currentProgress = 1.0
            logger.info("Backup restored successfully")
            
            return true
            
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Export Operations
    
    func exportData(
        template: ExportTemplate,
        context: ModelContext
    ) async -> URL? {
        guard !isExporting else {
            logger.warning("Export already in progress")
            return nil
        }
        
        isExporting = true
        currentProgress = 0.0
        currentOperation = "Preparing export..."
        
        defer {
            isExporting = false
            currentProgress = 0.0
            currentOperation = ""
        }
        
        do {
            currentOperation = "Collecting data for export..."
            currentProgress = 0.2
            
            let exportData = await collectExportData(template: template, context: context)
            
            currentOperation = "Generating export file..."
            currentProgress = 0.6
            
            let exportContent = try generateExportContent(data: exportData, format: template.format, template: template)
            
            currentOperation = "Saving export file..."
            currentProgress = 0.9
            
            let fileName = generateExportFileName(template: template)
            let fileURL = try saveExportToFile(content: exportContent, fileName: fileName, format: template.format)
            
            template.updateUsage()
            try context.save()
            
            currentProgress = 1.0
            logger.info("Export completed: \(fileName)")
            
            return fileURL
            
        } catch {
            logger.error("Export failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Import Operations
    
    func importData(
        from fileURL: URL,
        format: BackupFormat,
        conflictResolution: ConflictResolution = .skip,
        context: ModelContext
    ) async -> ImportRecord? {
        guard !isImporting else {
            logger.warning("Import already in progress")
            return nil
        }
        
        isImporting = true
        currentProgress = 0.0
        currentOperation = "Preparing import..."
        
        defer {
            isImporting = false
            currentProgress = 0.0
            currentOperation = ""
        }
        
        let importRecord = ImportRecord(
            fileName: fileURL.lastPathComponent,
            format: format,
            source: .file
        )
        importRecord.conflictResolution = conflictResolution
        
        context.insert(importRecord)
        
        do {
            currentOperation = "Reading import file..."
            currentProgress = 0.1
            
            let fileData = try Data(contentsOf: fileURL)
            importRecord.fileSize = Int64(fileData.count)
            
            currentOperation = "Parsing import data..."
            currentProgress = 0.3
            
            let parsedData = try parseImportContent(data: fileData, format: format)
            importRecord.totalItems = calculateTotalItems(parsedData: parsedData)
            
            currentOperation = "Importing data..."
            currentProgress = 0.5
            
            let importResult = await importDataToContext(
                parsedData: parsedData,
                conflictResolution: conflictResolution,
                context: context
            )
            
            currentOperation = "Finalizing import..."
            currentProgress = 0.9
            
            importRecord.updateProgress(
                imported: importResult.imported,
                skipped: importResult.skipped,
                errors: importResult.errors
            )
            
            importRecord.remindersImported = importResult.remindersImported
            importRecord.habitsImported = importResult.habitsImported
            importRecord.timeEntriesImported = importResult.timeEntriesImported
            importRecord.focusSessionsImported = importResult.focusSessionsImported
            
            importRecord.markAsCompleted()
            
            try context.save()
            
            currentProgress = 1.0
            logger.info("Import completed: \(importRecord.fileName)")
            
            return importRecord
            
        } catch {
            importRecord.markAsFailed(error: error.localizedDescription)
            try? context.save()
            logger.error("Import failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Template Management
    
    func createExportTemplate(
        name: String,
        format: BackupFormat,
        configuration: ExportTemplateConfiguration,
        context: ModelContext
    ) -> ExportTemplate {
        let template = ExportTemplate(name: name, format: format)
        template.backupDescription = configuration.templateDescription ?? ""
        template.includeReminders = configuration.includeReminders
        template.includeHabits = configuration.includeHabits
        template.includeTimeTracking = configuration.includeTimeTracking
        template.includeFocusSessions = configuration.includeFocusSessions
        template.includeCollaboration = configuration.includeCollaboration
        template.includeAIData = configuration.includeAIData
        template.includeCompletedItems = configuration.includeCompletedItems
        template.dateRange = configuration.dateRange
        template.customStartDate = configuration.customStartDate
        template.customEndDate = configuration.customEndDate
        template.filterByTags = try? JSONEncoder().encode(configuration.filterByTags)
        template.filterByLists = try? JSONEncoder().encode(configuration.filterByLists)
        template.filterByPriority = try? JSONEncoder().encode(configuration.filterByPriority)
        
        context.insert(template)
        
        do {
            try context.save()
            logger.info("Created export template: \(name)")
        } catch {
            logger.error("Failed to create export template: \(error.localizedDescription)")
        }
        
        return template
    }
    
    func getExportTemplates(context: ModelContext) -> [ExportTemplate] {
        let descriptor = FetchDescriptor<ExportTemplate>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.name)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    // MARK: - Backup History
    
    func getBackupHistory(userId: String, context: ModelContext) -> [BackupRecord] {
        let descriptor = FetchDescriptor<BackupRecord>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func getImportHistory(context: ModelContext) -> [ImportRecord] {
        let descriptor = FetchDescriptor<ImportRecord>(
            sortBy: [SortDescriptor(\.importedAt, order: .reverse)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    // MARK: - Cleanup Operations
    
    private func cleanupOldBackups(userId: String, maxBackups: Int, context: ModelContext) async {
        let completedStatusRaw = BackupStatus.completed.rawValue
        let descriptor = FetchDescriptor<BackupRecord>(
            predicate: #Predicate { $0.userId == userId && $0.statusRaw == completedStatusRaw },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        let backups = (try? context.fetch(descriptor)) ?? []
        
        if backups.count > maxBackups {
            let backupsToDelete = Array(backups.dropFirst(maxBackups))
            
            for backup in backupsToDelete {
                // Delete file
                let fileURL = URL(fileURLWithPath: backup.filePath)
                try? FileManager.default.removeItem(at: fileURL)
                
                // Delete record
                context.delete(backup)
            }
            
            do {
                try context.save()
                logger.info("Cleaned up \(backupsToDelete.count) old backups")
            } catch {
                logger.error("Failed to cleanup old backups: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Periodic Backup
    
    private func setupPeriodicBackup() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAndPerformScheduledBackup()
            }
        }
    }
    
    private func checkAndPerformScheduledBackup() async {
        // This would check if any users have scheduled backups due
        // Implementation would require access to model context
        logger.info("Checking for scheduled backups")
    }
    
    // MARK: - Helper Methods
    
    private func generateBackupFileName(type: BackupType, format: BackupFormat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        return "a-do_backup_\(type.rawValue)_\(timestamp).\(format.fileExtension)"
    }
    
    private func generateExportFileName(template: ExportTemplate) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        let safeName = template.name.replacingOccurrences(of: " ", with: "_")
        return "a-do_export_\(safeName)_\(timestamp).\(template.format.fileExtension)"
    }
    
    private func calculateChecksum(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func compressData(_ data: Data) throws -> Data {
        // Implementation would use compression algorithm
        // For now, return original data
        return data
    }
    
    private func decompressData(_ data: Data) throws -> Data {
        // Implementation would decompress data
        // For now, return original data
        return data
    }
    
    private func encryptData(_ data: Data, userId: String) throws -> Data {
        // Implementation would encrypt data using user-specific key
        // For now, return original data
        return data
    }
    
    private func decryptData(_ data: Data, userId: String) throws -> Data {
        // Implementation would decrypt data using user-specific key
        // For now, return original data
        return data
    }
    
    private func saveBackupToFile(content: Data, fileName: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let backupsPath = documentsPath.appendingPathComponent("Backups", isDirectory: true)
        
        // Create backups directory if it doesn't exist
        try FileManager.default.createDirectory(at: backupsPath, withIntermediateDirectories: true)
        
        let fileURL = backupsPath.appendingPathComponent(fileName)
        try content.write(to: fileURL)
        
        return fileURL
    }
    
    private func saveExportToFile(content: Data, fileName: String, format: BackupFormat) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportsPath = documentsPath.appendingPathComponent("Exports", isDirectory: true)
        
        // Create exports directory if it doesn't exist
        try FileManager.default.createDirectory(at: exportsPath, withIntermediateDirectories: true)
        
        let fileURL = exportsPath.appendingPathComponent(fileName)
        try content.write(to: fileURL)
        
        return fileURL
    }
    
    // MARK: - Data Collection and Generation (Placeholder implementations)
    
    private func collectBackupData(config: BackupConfiguration, context: ModelContext) async -> BackupData {
        // Implementation would collect data based on configuration
        return BackupData(
            reminders: [],
            habits: [],
            timeEntries: [],
            focusSessions: [],
            collaborationData: [],
            aiData: []
        )
    }
    
    private func collectExportData(template: ExportTemplate, context: ModelContext) async -> ExportData {
        // Implementation would collect data based on template settings
        return ExportData(
            reminders: [],
            habits: [],
            timeEntries: [],
            focusSessions: []
        )
    }
    
    private func generateBackupContent(data: BackupData, format: BackupFormat) throws -> Data {
        // Implementation would generate content in specified format
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(data)
    }
    
    private func generateExportContent(data: ExportData, format: BackupFormat, template: ExportTemplate) throws -> Data {
        // Implementation would generate export content based on format and template
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(data)
        case .csv:
            return try generateCSVContent(data: data)
        default:
            let encoder = JSONEncoder()
            return try encoder.encode(data)
        }
    }
    
    private func generateCSVContent(data: ExportData) throws -> Data {
        // Implementation would generate CSV content
        var csv = "Type,Title,Description,Date,Status\n"
        
        for reminder in data.reminders {
            csv += "Reminder,\(reminder.title),\(reminder.details ?? ""),\(reminder.createdAt),\(reminder.isCompleted ? "Completed" : "Pending")\n"
        }
        
        return csv.data(using: .utf8) ?? Data()
    }
    
    private func parseBackupContent(data: Data, format: BackupFormat) throws -> ParsedBackupData {
        // Implementation would parse backup content
        return ParsedBackupData()
    }
    
    private func parseImportContent(data: Data, format: BackupFormat) throws -> ParsedImportData {
        // Implementation would parse import content
        return ParsedImportData()
    }
    
    private func restoreDataToContext(parsedData: ParsedBackupData, context: ModelContext) async {
        // Implementation would restore parsed data to context
    }
    
    private func importDataToContext(
        parsedData: ParsedImportData,
        conflictResolution: ConflictResolution,
        context: ModelContext
    ) async -> ImportResult {
        // Implementation would import parsed data to context
        return ImportResult(
            imported: 0,
            skipped: 0,
            errors: 0,
            remindersImported: 0,
            habitsImported: 0,
            timeEntriesImported: 0,
            focusSessionsImported: 0
        )
    }
    
    private func calculateTotalItems(parsedData: ParsedImportData) -> Int {
        // Implementation would calculate total items in parsed data
        return 0
    }
}

// MARK: - Supporting Types

struct BackupData: Codable {
    let reminders: [ReminderBackupData]
    let habits: [HabitBackupData]
    let timeEntries: [TimeEntryBackupData]
    let focusSessions: [FocusSessionBackupData]
    let collaborationData: [SharedReminderBackupData]
    let aiData: [AISuggestionBackupData]
}

struct ExportData: Codable {
    let reminders: [ReminderBackupData]
    let habits: [HabitBackupData]
    let timeEntries: [TimeEntryBackupData]
    let focusSessions: [FocusSessionBackupData]
}

// MARK: - Backup Data Transfer Objects

struct ReminderBackupData: Codable {
    let uuid: UUID
    let title: String
    let details: String?
    let isCompleted: Bool
    let dueDate: Date?
    let createdAt: Date
    let completedAt: Date?
}

struct HabitBackupData: Codable {
    let id: UUID
    let title: String
    let habitDescription: String
    let isActive: Bool
    let createdAt: Date
}

struct TimeEntryBackupData: Codable {
    let id: UUID
    let category: String
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
}

struct FocusSessionBackupData: Codable {
    let id: UUID
    let name: String
    let sessionDescription: String
    let startTime: Date
    let endTime: Date?
    let plannedDuration: TimeInterval
    let actualDuration: TimeInterval
}

struct SharedReminderBackupData: Codable {
    let id: UUID
    let reminderID: UUID
    let ownerID: String
    let ownerName: String
    let shareTitle: String
    let sharedAt: Date
}

struct AISuggestionBackupData: Codable {
    let id: UUID
    let title: String
    let aiDescription: String
    let confidence: Double
    let createdAt: Date
}

struct ExportTemplateConfiguration {
    let templateDescription: String?
    let includeReminders: Bool
    let includeHabits: Bool
    let includeTimeTracking: Bool
    let includeFocusSessions: Bool
    let includeCollaboration: Bool
    let includeAIData: Bool
    let includeCompletedItems: Bool
    let dateRange: ExportDateRange
    let customStartDate: Date?
    let customEndDate: Date?
    let filterByTags: [String]
    let filterByLists: [String]
    let filterByPriority: [Priority]
}

struct ParsedBackupData {
    // Parsed backup data structure
}

struct ParsedImportData {
    // Parsed import data structure
}

struct ImportResult {
    let imported: Int
    let skipped: Int
    let errors: Int
    let remindersImported: Int
    let habitsImported: Int
    let timeEntriesImported: Int
    let focusSessionsImported: Int
}

