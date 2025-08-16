import Foundation
import SwiftData
import os

enum AppContainer {
    static var container: ModelContainer = {
        let schema = Schema([
            Reminder.self,
            Tag.self,
            ReminderList.self,
            ReminderNotification.self,
            LocationTrigger.self,
            ListSection.self,
            TaggedContact.self
        ])

        // Default to a local persistent store. Enable CloudKit later when entitlements are configured.
        do {
            let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let localContainer = try ModelContainer(for: schema, configurations: [localConfig])
            #if DEBUG
            print("✅ SwiftData local persistent container initialized")
            #endif
            return localContainer
        } catch {
            // Last resort: in-memory
            do {
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                let memoryContainer = try ModelContainer(for: schema, configurations: [memoryConfig])
                #if DEBUG
                print("⚠️ Using in-memory SwiftData container due to init error: \(error)")
                #endif
                return memoryContainer
            } catch {
                // Graceful fallback: return a basic in-memory container
                #if DEBUG
                print("❌ Critical: Unable to initialize any SwiftData container: \(error)")
                #endif
                // Create a minimal in-memory container as last resort
                let minimalConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                if let minimalContainer = try? ModelContainer(for: schema, configurations: [minimalConfig]) {
                    return minimalContainer
                } else {
                    // If even the minimal container fails, the app cannot function
                    // This should be extremely rare and indicates a system-level issue
                    return ModelContainer(for: Reminder.self, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
                }
            }
        }
    }()
}


