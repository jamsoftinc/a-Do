//
//  BackupModels.swift
//  a-do
//
//  Backup and export models
//

import Foundation
import SwiftData

// MARK: - Backup Configuration
@Model
final class BackupConfiguration {
    var id: UUID = UUID()
    var userId: String = ""
    var isEnabled: Bool = true
    var frequency: BackupFrequency = BackupFrequency.weekly
    var includeCompletedReminders: Bool = false
    var includeHabits: Bool = true
    var includeTimeTracking: Bool = true
    var includeFocusSessions: Bool = true
    var includeCollaboration: Bool = false
    var includeAIData: Bool = false
    var maxBackupsToKeep: Int = 10
    var compressionEnabled: Bool = true
    var encryptionEnabled: Bool = true
    var cloudBackupEnabled: Bool = true
    var localBackupEnabled: Bool = true
    var lastBackupDate: Date?
    var nextBackupDate: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(userId: String) {
        self.userId = userId
        self.createdAt = Date()
        self.updatedAt = Date()
        calculateNextBackupDate()
    }
    
    func calculateNextBackupDate() {
        let calendar = Calendar.current
        let now = Date()
        
        switch frequency {
        case .daily:
            nextBackupDate = calendar.date(byAdding: .day, value: 1, to: now)
        case .weekly:
            nextBackupDate = calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        case .monthly:
            nextBackupDate = calendar.date(byAdding: .month, value: 1, to: now)
        case .manual:
            nextBackupDate = nil
        }
    }
    
    func updateSettings() {
        updatedAt = Date()
        calculateNextBackupDate()
    }
}

// MARK: - Backup Frequency
enum BackupFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .manual: return "Manual Only"
        }
    }
}

// MARK: - Backup Record
@Model
final class BackupRecord {
    var id: UUID = UUID()
    var userId: String = ""
    var fileName: String = ""
    var filePath: String = ""
    var fileSize: Int64 = 0
    var createdAt: Date = Date()
    var backupType: BackupType = BackupType.full
    var format: BackupFormat = BackupFormat.json
    var isCompressed: Bool = false
    var isEncrypted: Bool = false
    var isCloudBacked: Bool = false
    var checksum: String = ""
    var version: String = "1.0"
    var status: BackupStatus = BackupStatus.inProgress
    var errorMessage: String?
    
    // Metadata
    var reminderCount: Int = 0
    var habitCount: Int = 0
    var timeEntryCount: Int = 0
    var focusSessionCount: Int = 0
    var collaborationCount: Int = 0
    
    init(userId: String, fileName: String, backupType: BackupType = .full) {
        self.userId = userId
        self.fileName = fileName
        self.backupType = backupType
        self.createdAt = Date()
    }
    
    func markAsCompleted(fileSize: Int64, checksum: String) {
        self.fileSize = fileSize
        self.checksum = checksum
        self.status = .completed
    }
    
    func markAsFailed(error: String) {
        self.errorMessage = error
        self.status = .failed
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

// MARK: - Backup Type
enum BackupType: String, CaseIterable, Codable {
    case full = "full"
    case incremental = "incremental"
    case selective = "selective"
    
    var displayName: String {
        switch self {
        case .full: return "Full Backup"
        case .incremental: return "Incremental Backup"
        case .selective: return "Selective Backup"
        }
    }
    
    var description: String {
        switch self {
        case .full: return "Complete backup of all data"
        case .incremental: return "Only changes since last backup"
        case .selective: return "Selected data categories only"
        }
    }
}

// MARK: - Backup Format
enum BackupFormat: String, CaseIterable, Codable {
    case json = "json"
    case csv = "csv"
    case xml = "xml"
    case plist = "plist"
    case sqlite = "sqlite"
    
    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .xml: return "XML"
        case .plist: return "Property List"
        case .sqlite: return "SQLite Database"
        }
    }
    
    var fileExtension: String {
        return rawValue
    }
    
    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        case .xml: return "application/xml"
        case .plist: return "application/x-plist"
        case .sqlite: return "application/x-sqlite3"
        }
    }
}

// MARK: - Backup Status
enum BackupStatus: String, CaseIterable, Codable {
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .inProgress: return "#007AFF"
        case .completed: return "#34C759"
        case .failed: return "#FF3B30"
        case .cancelled: return "#8E8E93"
        }
    }
}

// MARK: - Export Template
@Model
final class ExportTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var backupDescription: String = ""
    var format: BackupFormat = BackupFormat.json
    var includeReminders: Bool = true
    var includeHabits: Bool = true
    var includeTimeTracking: Bool = true
    var includeFocusSessions: Bool = true
    var includeCollaboration: Bool = false
    var includeAIData: Bool = false
    var includeCompletedItems: Bool = false
    var dateRange: ExportDateRange = ExportDateRange.all
    var customStartDate: Date?
    var customEndDate: Date?
    var filterByTags: [String] = []
    var filterByLists: [String] = []
    var filterByPriority: [Priority] = []
    var isActive: Bool = true
    var usageCount: Int = 0
    var lastUsed: Date?
    var createdAt: Date = Date()
    
    init(name: String, format: BackupFormat = .json) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.format = format
        self.createdAt = Date()
    }
    
    func updateUsage() {
        usageCount += 1
        lastUsed = Date()
    }
}

// MARK: - Export Date Range
enum ExportDateRange: String, CaseIterable, Codable {
    case all = "all"
    case lastWeek = "last_week"
    case lastMonth = "last_month"
    case lastYear = "last_year"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .all: return "All Time"
        case .lastWeek: return "Last Week"
        case .lastMonth: return "Last Month"
        case .lastYear: return "Last Year"
        case .custom: return "Custom Range"
        }
    }
    
    func getDateRange() -> (start: Date?, end: Date?) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .all:
            return (nil, nil)
        case .lastWeek:
            let start = calendar.date(byAdding: .weekOfYear, value: -1, to: now)
            return (start, now)
        case .lastMonth:
            let start = calendar.date(byAdding: .month, value: -1, to: now)
            return (start, now)
        case .lastYear:
            let start = calendar.date(byAdding: .year, value: -1, to: now)
            return (start, now)
        case .custom:
            return (nil, nil) // Will use customStartDate and customEndDate
        }
    }
}

// MARK: - Import Record
@Model
final class ImportRecord {
    var id: UUID = UUID()
    var fileName: String = ""
    var originalFileName: String = ""
    var fileSize: Int64 = 0
    var format: BackupFormat = BackupFormat.json
    var source: ImportSource = ImportSource.file
    var importedAt: Date = Date()
    var status: ImportStatus = ImportStatus.inProgress
    var errorMessage: String?
    var conflictResolution: ConflictResolution = ConflictResolution.skip
    
    // Import statistics
    var totalItems: Int = 0
    var importedItems: Int = 0
    var skippedItems: Int = 0
    var errorItems: Int = 0
    var duplicateItems: Int = 0
    
    // Data breakdown
    var remindersImported: Int = 0
    var habitsImported: Int = 0
    var timeEntriesImported: Int = 0
    var focusSessionsImported: Int = 0
    
    init(fileName: String, format: BackupFormat, source: ImportSource = .file) {
        self.fileName = fileName
        self.originalFileName = fileName
        self.format = format
        self.source = source
        self.importedAt = Date()
    }
    
    func updateProgress(imported: Int, skipped: Int, errors: Int) {
        self.importedItems = imported
        self.skippedItems = skipped
        self.errorItems = errors
    }
    
    func markAsCompleted() {
        self.status = .completed
    }
    
    func markAsFailed(error: String) {
        self.errorMessage = error
        self.status = .failed
    }
    
    var successRate: Double {
        guard totalItems > 0 else { return 0 }
        return Double(importedItems) / Double(totalItems)
    }
}

// MARK: - Import Source
enum ImportSource: String, CaseIterable, Codable {
    case file = "file"
    case url = "url"
    case clipboard = "clipboard"
    case airdrop = "airdrop"
    case icloud = "icloud"
    case backup = "backup"
    
    var displayName: String {
        switch self {
        case .file: return "File"
        case .url: return "URL"
        case .clipboard: return "Clipboard"
        case .airdrop: return "AirDrop"
        case .icloud: return "iCloud"
        case .backup: return "Backup Restore"
        }
    }
}

// MARK: - Import Status
enum ImportStatus: String, CaseIterable, Codable {
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    case partialSuccess = "partial_success"
    
    var displayName: String {
        switch self {
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        case .partialSuccess: return "Partial Success"
        }
    }
}

// MARK: - Conflict Resolution
enum ConflictResolution: String, CaseIterable, Codable {
    case skip = "skip"
    case overwrite = "overwrite"
    case merge = "merge"
    case keepBoth = "keep_both"
    case askUser = "ask_user"
    
    var displayName: String {
        switch self {
        case .skip: return "Skip Duplicates"
        case .overwrite: return "Overwrite Existing"
        case .merge: return "Merge Data"
        case .keepBoth: return "Keep Both"
        case .askUser: return "Ask Each Time"
        }
    }
    
    var description: String {
        switch self {
        case .skip: return "Skip items that already exist"
        case .overwrite: return "Replace existing items with imported ones"
        case .merge: return "Combine data from both sources"
        case .keepBoth: return "Create new items for duplicates"
        case .askUser: return "Prompt for each conflict"
        }
    }
}

// MARK: - Sync Configuration
@Model
final class SyncConfiguration {
    var id: UUID = UUID()
    var userId: String = ""
    var isEnabled: Bool = true
    var syncProvider: SyncProvider = SyncProvider.icloud
    var autoSyncEnabled: Bool = true
    var syncInterval: TimeInterval = 300 // 5 minutes
    var conflictResolution: ConflictResolution = ConflictResolution.merge
    var lastSyncDate: Date?
    var nextSyncDate: Date?
    var syncOnlyOnWiFi: Bool = false
    var syncInBackground: Bool = true
    var notifyOnSyncCompletion: Bool = false
    var retryFailedSyncs: Bool = true
    var maxRetryAttempts: Int = 3
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(userId: String) {
        self.userId = userId
        self.createdAt = Date()
        self.updatedAt = Date()
        calculateNextSyncDate()
    }
    
    func calculateNextSyncDate() {
        guard autoSyncEnabled else {
            nextSyncDate = nil
            return
        }
        
        nextSyncDate = Date().addingTimeInterval(syncInterval)
    }
    
    func updateSettings() {
        updatedAt = Date()
        calculateNextSyncDate()
    }
}

// MARK: - Sync Provider
enum SyncProvider: String, CaseIterable, Codable {
    case icloud = "icloud"
    case dropbox = "dropbox"
    case googleDrive = "google_drive"
    case onedrive = "onedrive"
    case webdav = "webdav"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .icloud: return "iCloud"
        case .dropbox: return "Dropbox"
        case .googleDrive: return "Google Drive"
        case .onedrive: return "OneDrive"
        case .webdav: return "WebDAV"
        case .custom: return "Custom Server"
        }
    }
    
    var icon: String {
        switch self {
        case .icloud: return "icloud"
        case .dropbox: return "folder"
        case .googleDrive: return "folder"
        case .onedrive: return "folder"
        case .webdav: return "server.rack"
        case .custom: return "externaldrive"
        }
    }
}

// MARK: - Sync Record
@Model
final class SyncRecord {
    var id: UUID = UUID()
    var userId: String = ""
    var provider: SyncProvider = SyncProvider.icloud
    var syncType: SyncType = SyncType.full
    var startedAt: Date = Date()
    var completedAt: Date?
    var status: SyncStatus = SyncStatus.inProgress
    var direction: SyncDirection = SyncDirection.bidirectional
    var itemsSynced: Int = 0
    var itemsSkipped: Int = 0
    var itemsConflicted: Int = 0
    var errorMessage: String?
    var dataTransferred: Int64 = 0
    
    init(userId: String, provider: SyncProvider, syncType: SyncType = .full) {
        self.userId = userId
        self.provider = provider
        self.syncType = syncType
        self.startedAt = Date()
    }
    
    func complete(itemsSynced: Int, itemsSkipped: Int, conflicts: Int, dataSize: Int64) {
        self.completedAt = Date()
        self.status = .completed
        self.itemsSynced = itemsSynced
        self.itemsSkipped = itemsSkipped
        self.itemsConflicted = conflicts
        self.dataTransferred = dataSize
    }
    
    func fail(error: String) {
        self.completedAt = Date()
        self.status = .failed
        self.errorMessage = error
    }
    
    var duration: TimeInterval {
        guard let completedAt = completedAt else {
            return Date().timeIntervalSince(startedAt)
        }
        return completedAt.timeIntervalSince(startedAt)
    }
}

// MARK: - Sync Type
enum SyncType: String, CaseIterable, Codable {
    case full = "full"
    case incremental = "incremental"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .full: return "Full Sync"
        case .incremental: return "Incremental Sync"
        case .manual: return "Manual Sync"
        }
    }
}

// MARK: - Sync Status
enum SyncStatus: String, CaseIterable, Codable {
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    case paused = "paused"
    
    var displayName: String {
        switch self {
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        case .paused: return "Paused"
        }
    }
}

// MARK: - Sync Direction
enum SyncDirection: String, CaseIterable, Codable {
    case upload = "upload"
    case download = "download"
    case bidirectional = "bidirectional"
    
    var displayName: String {
        switch self {
        case .upload: return "Upload Only"
        case .download: return "Download Only"
        case .bidirectional: return "Two-Way Sync"
        }
    }
}
