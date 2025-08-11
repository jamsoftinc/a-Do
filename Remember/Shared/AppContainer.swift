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
            print("✅ SwiftData local persistent container initialized")
            return localContainer
        } catch {
            // Last resort: in-memory
            do {
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                let memoryContainer = try ModelContainer(for: schema, configurations: [memoryConfig])
                print("⚠️ Using in-memory SwiftData container due to init error: \(error)")
                return memoryContainer
            } catch {
                fatalError("Unable to initialize any SwiftData container: \(error)")
            }
        }
    }()
}


