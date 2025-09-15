import Foundation
import SwiftData
import os

@MainActor
@Observable
final class SettingsManager {
    static let shared = SettingsManager()
    
    private var settings: AppSettings?
    private let logger = Logger(subsystem: "a-do", category: "Settings")
    
    private init() {}
    
    // MARK: - Settings Access
    
    func getSettings(context: ModelContext) -> AppSettings {
        if let existingSettings = settings {
            return existingSettings
        }
        
        // Try to fetch existing settings
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            settings = existing
            return existing
        }
        
        // Create new settings
        let newSettings = AppSettings()
        context.insert(newSettings)
        settings = newSettings
        
        do {
            try context.save()
            logger.info("Created new app settings")
        } catch {
            logger.error("Failed to save new settings: \(String(describing: error))")
        }
        
        return newSettings
    }
    
    // MARK: - Apple Integration Settings
    
    func setAppleRemindersEnabled(_ enabled: Bool, context: ModelContext) {
        let settings = getSettings(context: context)
        settings.appleRemindersEnabled = enabled
        
        saveSettings(context: context)
        
        if enabled {
            logger.info("Apple Reminders integration enabled")
        } else {
            logger.info("Apple Reminders integration disabled")
        }
    }
    
    func setAppleCalendarEnabled(_ enabled: Bool, context: ModelContext) {
        let settings = getSettings(context: context)
        settings.appleCalendarEnabled = enabled
        
        saveSettings(context: context)
        
        if enabled {
            logger.info("Apple Calendar integration enabled")
        } else {
            logger.info("Apple Calendar integration disabled")
        }
    }
    
    func setAppleNotesEnabled(_ enabled: Bool, context: ModelContext) {
        let settings = getSettings(context: context)
        settings.appleNotesEnabled = enabled
        
        saveSettings(context: context)
        
        if enabled {
            logger.info("Apple Notes integration enabled")
        } else {
            logger.info("Apple Notes integration disabled")
        }
    }
    
    func setICloudSyncEnabled(_ enabled: Bool, context: ModelContext) {
        let settings = getSettings(context: context)
        settings.iCloudSyncEnabled = enabled
        
        saveSettings(context: context)
        
        // Update CloudKitManager
        CloudKitManager.shared.setSyncEnabled(enabled)
        
        if enabled {
            logger.info("iCloud sync enabled")
        } else {
            logger.info("iCloud sync disabled")
        }
    }
    
    // MARK: - Sync Settings
    
    func setAutoSyncEnabled(_ enabled: Bool, context: ModelContext) {
        let settings = getSettings(context: context)
        settings.autoSyncEnabled = enabled
        
        saveSettings(context: context)
        
        if enabled {
            logger.info("Auto sync enabled")
        } else {
            logger.info("Auto sync disabled")
        }
    }
    
    func setSyncInterval(_ interval: TimeInterval, context: ModelContext) {
        let settings = getSettings(context: context)
        settings.syncInterval = interval
        
        saveSettings(context: context)
        logger.info("Sync interval set to \(interval) seconds")
    }
    
    func markFirstSyncCompleted(context: ModelContext) {
        let settings = getSettings(context: context)
        settings.isFirstSyncCompleted = true
        
        saveSettings(context: context)
        logger.info("First sync marked as completed")
    }
    
    func isFirstSync(context: ModelContext) -> Bool {
        let settings = getSettings(context: context)
        return !settings.isFirstSyncCompleted
    }
    
    // MARK: - Notification Settings
    
    func setNotificationsEnabled(_ enabled: Bool, context: ModelContext) {
        let settings = getSettings(context: context)
        settings.notificationsEnabled = enabled
        
        saveSettings(context: context)
        
        if enabled {
            logger.info("Notifications enabled")
        } else {
            logger.info("Notifications disabled")
        }
    }
    
    func setSoundEnabled(_ enabled: Bool, context: ModelContext) {
        let settings = getSettings(context: context)
        settings.soundEnabled = enabled
        
        saveSettings(context: context)
        
        if enabled {
            logger.info("Notification sounds enabled")
        } else {
            logger.info("Notification sounds disabled")
        }
    }
    
    func setBadgeEnabled(_ enabled: Bool, context: ModelContext) {
        let settings = getSettings(context: context)
        settings.badgeEnabled = enabled
        
        saveSettings(context: context)
        
        if enabled {
            logger.info("App badge enabled")
        } else {
            logger.info("App badge disabled")
        }
    }
    
    // MARK: - Privacy Settings
    
    func setLocationEnabled(_ enabled: Bool, context: ModelContext) {
        let settings = getSettings(context: context)
        settings.locationEnabled = enabled
        
        saveSettings(context: context)
        
        if enabled {
            logger.info("Location access enabled")
        } else {
            logger.info("Location access disabled")
        }
    }
    
    func setContactsEnabled(_ enabled: Bool, context: ModelContext) {
        let settings = getSettings(context: context)
        settings.contactsEnabled = enabled
        
        saveSettings(context: context)
        
        if enabled {
            logger.info("Contacts access enabled")
        } else {
            logger.info("Contacts access disabled")
        }
    }
    
    func setMicrophoneEnabled(_ enabled: Bool, context: ModelContext) {
        let settings = getSettings(context: context)
        settings.microphoneEnabled = enabled
        
        saveSettings(context: context)
        
        if enabled {
            logger.info("Microphone access enabled")
        } else {
            logger.info("Microphone access disabled")
        }
    }
    
    // MARK: - UI Settings
    
    func setTheme(_ theme: String, context: ModelContext) {
        let settings = getSettings(context: context)
        settings.theme = theme
        
        saveSettings(context: context)
        logger.info("Theme set to \(theme)")
    }
    
    func setAccentColor(_ color: String, context: ModelContext) {
        let settings = getSettings(context: context)
        settings.accentColor = color
        
        saveSettings(context: context)
        logger.info("Accent color set to \(color)")
    }
    
    // MARK: - Data Settings
    
    func setAutoBackupEnabled(_ enabled: Bool, context: ModelContext) {
        let settings = getSettings(context: context)
        settings.autoBackupEnabled = enabled
        
        saveSettings(context: context)
        
        if enabled {
            logger.info("Auto backup enabled")
        } else {
            logger.info("Auto backup disabled")
        }
    }
    
    func setBackupFrequency(_ frequency: String, context: ModelContext) {
        let settings = getSettings(context: context)
        settings.backupFrequency = frequency
        
        saveSettings(context: context)
        logger.info("Backup frequency set to \(frequency)")
    }
    
    // MARK: - Settings Validation
    
    func validateSettings(context: ModelContext) -> [String] {
        let settings = getSettings(context: context)
        return settings.validateSettings()
    }
    
    // MARK: - Settings Reset
    
    func resetToDefaults(context: ModelContext) {
        let settings = getSettings(context: context)
        
        // Reset to default values
        settings.appleRemindersEnabled = true
        settings.appleCalendarEnabled = true
        settings.appleNotesEnabled = true
        settings.iCloudSyncEnabled = true
        settings.autoSyncEnabled = true
        settings.syncInterval = 300
        settings.isFirstSyncCompleted = false
        settings.notificationsEnabled = true
        settings.soundEnabled = true
        settings.badgeEnabled = true
        settings.locationEnabled = true
        settings.contactsEnabled = true
        settings.microphoneEnabled = true
        settings.theme = "system"
        settings.accentColor = "#7C4DFF"
        settings.autoBackupEnabled = true
        settings.backupFrequency = "weekly"
        
        saveSettings(context: context)
        logger.info("Settings reset to defaults")
    }
    
    // MARK: - Private Methods
    
    private func saveSettings(context: ModelContext) {
        do {
            try context.save()
        } catch {
            logger.error("Failed to save settings: \(String(describing: error))")
        }
    }
}
