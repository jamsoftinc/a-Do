import Foundation
import SwiftData
import os

enum AppContainer {
    static let cloudKitContainerId = "iCloud.JAMSoft.Remember"

    static var container: ModelContainer = {
        let schema = Schema([
            Reminder.self,
            Tag.self,
            ReminderList.self,
            ReminderNotification.self,
            LocationTrigger.self,
            ListSection.self
        ])

        // Preferred: CloudKit-backed container
        do {
            let cloudConfig = ModelConfiguration(
                cloudKitContainerId,
                schema: schema,
                isStoredInMemoryOnly: false
            )
            let cloudContainer = try ModelContainer(for: schema, configurations: [cloudConfig])
            print("✅ SwiftData CloudKit container initialized")
            return cloudContainer
        } catch {
            print("⚠️ CloudKit init failed: \(error). Falling back to local store.")
            // Fallback: local persistent store
            do {
                let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, allowsSave: true)
                let localContainer = try ModelContainer(for: schema, configurations: [localConfig])
                print("✅ Local persistent container initialized")
                return localContainer
            } catch {
                // Last resort: in-memory
                do {
                    let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                    let memoryContainer = try ModelContainer(for: schema, configurations: [memoryConfig])
                    print("⚠️ Using in-memory container")
                    return memoryContainer
                } catch {
                    fatalError("Unable to initialize SwiftData container: \(error)")
                }
            }
        }
    }()
}


