import Foundation
import os

/// Utility class for safely accessing app group UserDefaults with fallbacks
final class AppGroupDefaults {
    static let shared = AppGroupDefaults()
    
    // MARK: - Constants
    private let appGroupIdentifier = "group.com.ado.app"
    private let logger = Logger(subsystem: "a-do", category: "AppGroupDefaults")
    
    // MARK: - Private Properties
    private var cachedDefaults: UserDefaults?
    
    private init() {
        // Check if we should force standard UserDefaults
        checkAndSetForceStandardIfNeeded()
    }
    
    deinit {
        // Clean up any cached references
        cachedDefaults = nil
    }
    
    // MARK: - Setup & Configuration
    
    /// Check if we should force standard UserDefaults and set the flag accordingly
    private func checkAndSetForceStandardIfNeeded() {
        #if targetEnvironment(simulator)
        // Always force standard in simulator
        forceStandardDefaults = true
        logger.info("Simulator detected - forcing standard UserDefaults")
        return
        #else
        // Check if app group access is causing issues
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            // Try to access a simple key to see if it causes issues
            let testKey = "app_group_test_\(UUID().uuidString)"
            appGroupDefaults.set("test", forKey: testKey)
            let result = appGroupDefaults.string(forKey: testKey)
            appGroupDefaults.removeObject(forKey: testKey)
            
            if result == "test" {
                logger.info("App group access test successful")
            } else {
                logger.warning("App group access test failed - forcing standard UserDefaults")
                forceStandardDefaults = true
            }
        } else {
            logger.warning("App group not accessible - forcing standard UserDefaults")
            forceStandardDefaults = true
        }
        #endif
    }
    
    // MARK: - UserDefaults Access
    
    /// Gets the appropriate UserDefaults instance with fallback
    /// - Returns: App group UserDefaults if accessible, otherwise standard UserDefaults
    var defaults: UserDefaults {
        return safeDefaults
    }
    
    /// Gets UserDefaults with force override option
    var safeDefaults: UserDefaults {
        if forceStandardDefaults {
            logger.warning("App group access force disabled - using standard UserDefaults")
            return .standard
        }
        
        // Use cached defaults if available
        if let cached = cachedDefaults {
            return cached
        }
        
        // Create and cache new defaults
        let defaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard
        cachedDefaults = defaults
        return defaults
    }
    
    // MARK: - Value Operations
    
    /// Safely sets a value in the appropriate UserDefaults
    /// - Parameters:
    ///   - value: The value to set
    ///   - key: The key for the value
    func set(_ value: Any?, forKey key: String) {
        let currentDefaults = defaults
        currentDefaults.set(value, forKey: key)
        
        // Note: synchronize() is deprecated - iOS handles this automatically
        
        logger.debug("Set value for key '\(key)' in \(currentDefaults == .standard ? "standard" : "app group") UserDefaults")
    }
    
    /// Safely gets a value from the appropriate UserDefaults
    /// - Parameter key: The key for the value
    /// - Returns: The value if found, nil otherwise
    func object(forKey key: String) -> Any? {
        let currentDefaults = defaults
        let value = currentDefaults.object(forKey: key)
        logger.debug("Retrieved value for key '\(key)' from \(currentDefaults == .standard ? "standard" : "app group") UserDefaults")
        return value
    }
    
    /// Safely gets a boolean value from the appropriate UserDefaults
    /// - Parameter key: The key for the value
    /// - Returns: The boolean value, false if not found
    func bool(forKey key: String) -> Bool {
        let currentDefaults = defaults
        let value = currentDefaults.bool(forKey: key)
        logger.debug("Retrieved boolean value for key '\(key)': \(value) from \(currentDefaults == .standard ? "standard" : "app group") UserDefaults")
        return value
    }
    
    /// Safely gets a string value from the appropriate UserDefaults
    /// - Parameter key: The key for the value
    /// - Returns: The string value if found, nil otherwise
    func string(forKey key: String) -> String? {
        let currentDefaults = defaults
        let value = currentDefaults.string(forKey: key)
        logger.debug("Retrieved string value for key '\(key)' from \(currentDefaults == .standard ? "standard" : "app group") UserDefaults")
        return value
    }
    
    /// Safely gets an integer value from the appropriate UserDefaults
    /// - Parameter key: The key for the value
    /// - Returns: The integer value, 0 if not found
    func integer(forKey key: String) -> Int {
        let currentDefaults = defaults
        let value = currentDefaults.integer(forKey: key)
        logger.debug("Retrieved integer value for key '\(key)': \(value) from \(currentDefaults == .standard ? "standard" : "app group") UserDefaults")
        return value
    }
    
    /// Safely gets a double value from the appropriate UserDefaults
    /// - Parameter key: The key for the value
    /// - Returns: The double value, 0.0 if not found
    func double(forKey key: String) -> Double {
        let currentDefaults = defaults
        let value = currentDefaults.double(forKey: key)
        logger.debug("Retrieved double value for key '\(key)': \(value) from \(currentDefaults == .standard ? "standard" : "app group") UserDefaults")
        return value
    }
    
    /// Safely gets data from the appropriate UserDefaults
    /// - Parameter key: The key for the value
    /// - Returns: The data if found, nil otherwise
    func data(forKey key: String) -> Data? {
        let currentDefaults = defaults
        let value = currentDefaults.data(forKey: key)
        logger.debug("Retrieved data for key '\(key)' from \(currentDefaults == .standard ? "standard" : "app group") UserDefaults")
        return value
    }
    
    /// Safely removes a value from the appropriate UserDefaults
    /// - Parameter key: The key for the value to remove
    func removeObject(forKey key: String) {
        let currentDefaults = defaults
        currentDefaults.removeObject(forKey: key)
        
        // Synchronize to ensure data is removed immediately
        currentDefaults.synchronize()
        
        logger.debug("Removed value for key '\(key)' from \(currentDefaults == .standard ? "standard" : "app group") UserDefaults")
    }
    
    // MARK: - Utility Methods
    
    /// Checks if the app group is currently accessible
    /// - Returns: True if app group is accessible, false otherwise
    var isAppGroupAccessible: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        guard let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return false
        }

        // Test accessibility by writing and reading a test value
        let testKey = "a_do_accessibility_test"
        let testValue = UUID().uuidString
        appGroupDefaults.set(testValue, forKey: testKey)
        let readValue = appGroupDefaults.string(forKey: testKey)
        appGroupDefaults.removeObject(forKey: testKey)

        return readValue == testValue
        #endif
    }
    
    /// Force disable app group access (useful for debugging or when app group causes issues)
    var forceStandardDefaults: Bool = false
    
    /// Manually force the use of standard UserDefaults (useful for debugging)
    func forceUseStandardDefaults() {
        forceStandardDefaults = true
        logger.warning("Manually forced standard UserDefaults")
    }
    
    /// Reset to automatic detection
    func resetToAutomaticDetection() {
        forceStandardDefaults = false
        cachedDefaults = nil
        checkAndSetForceStandardIfNeeded()
        logger.info("Reset to automatic UserDefaults detection")
    }
    
    /// Clear all cached data (useful for troubleshooting)
    func clearCache() {
        cachedDefaults = nil
        logger.info("Cleared UserDefaults cache")
    }
    
    /// Get information about the current UserDefaults configuration
    func getConfigurationInfo() -> [String: Any] {
        return [
            "isAppGroupAccessible": isAppGroupAccessible,
            "forceStandardDefaults": forceStandardDefaults,
            "currentDefaultsType": defaults == .standard ? "standard" : "app group",
            "appGroupIdentifier": appGroupIdentifier
        ]
    }
}
