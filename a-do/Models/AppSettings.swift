import Foundation
import SwiftData

@Model
final class AppSettings {
    // Apple Integrations
    var appleRemindersEnabled: Bool = true
    var appleCalendarEnabled: Bool = true
    var appleNotesEnabled: Bool = true
    
    // Sync Settings
    var autoSyncEnabled: Bool = true
    var syncInterval: TimeInterval = 300 // 5 minutes
    
    // Notification Settings
    var notificationsEnabled: Bool = true
    var soundEnabled: Bool = true
    var badgeEnabled: Bool = true
    
    // Privacy Settings
    var locationEnabled: Bool = true
    var contactsEnabled: Bool = true
    var microphoneEnabled: Bool = true
    
    // UI Settings
    var theme: String = "system" // "light", "dark", "system"
    var accentColor: String = "#7C4DFF"
    
    // Data Settings
    var autoBackupEnabled: Bool = true
    var backupFrequency: String = "weekly" // "daily", "weekly", "monthly"
    
    init() {
        // Default settings
    }
    
    // MARK: - Apple Integration Helpers
    
    var hasAnyAppleIntegration: Bool {
        return appleRemindersEnabled || appleCalendarEnabled || appleNotesEnabled
    }
    
    var integrationStatus: [String: Bool] {
        return [
            "Reminders": appleRemindersEnabled,
            "Calendar": appleCalendarEnabled,
            "Notes": appleNotesEnabled
        ]
    }
    
    // MARK: - Settings Validation
    
    func validateSettings() -> [String] {
        var warnings: [String] = []
        
        if !appleRemindersEnabled && !appleCalendarEnabled && !appleNotesEnabled {
            warnings.append("All Apple integrations are disabled. Some features may not work properly.")
        }
        
        if !notificationsEnabled {
            warnings.append("Notifications are disabled. You won't receive reminder alerts.")
        }
        
        if !locationEnabled {
            warnings.append("Location access is disabled. Location-based reminders won't work.")
        }
        
        return warnings
    }
}
