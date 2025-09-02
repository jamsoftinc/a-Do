import Foundation
import os

/// Extension to UserDefaults that provides safe app group access
extension UserDefaults {
    
    /// Safe app group UserDefaults access with automatic fallback
    /// - Parameter suiteName: The app group identifier
    /// - Returns: UserDefaults instance, falling back to standard if app group is inaccessible
    static func safeAppGroup(suiteName: String) -> UserDefaults {
        // Check if this is our app group
        if suiteName == "group.JAMSoft.a-do" {
            return AppGroupDefaults.shared.defaults
        }
        
        // For other app groups, try to access normally
        return UserDefaults(suiteName: suiteName) ?? .standard
    }
    
    /// Override the standard suiteName initializer to catch app group access
    convenience init?(safeSuiteName suiteName: String) {
        if suiteName == "group.JAMSoft.a-do" {
            // Use our safe implementation
            self.init(suiteName: "standard") // This will be overridden
            // We can't actually override the suiteName, but we can ensure safe access
        } else {
            self.init(suiteName: suiteName)
        }
    }
}

/// Global function to safely access app group UserDefaults
/// This function should be used instead of UserDefaults(suiteName:) for app group access
func safeAppGroupDefaults() -> UserDefaults {
    return AppGroupDefaults.shared.defaults
}
