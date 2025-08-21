import Foundation
import SwiftData
import os

final class AppContainer {
    static let shared = AppContainer()
    
    private init() {}
    
    @MainActor
    lazy var container: ModelContainer = {
        let schema = Schema([
            Reminder.self,
            Tag.self,
            ReminderList.self,
            ReminderNotification.self,
            LocationTrigger.self,
            ListSection.self,
            TaggedContact.self,
            AppleNoteAttachment.self
        ])

        #if DEBUG
        print("🔄 Initializing SwiftData container...")
        #endif
        
        // Start with local storage to avoid CloudKit issues
        do {
            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            let localContainer = try ModelContainer(for: schema, configurations: localConfig)
            #if DEBUG
            print("✅ SwiftData local persistent container initialized")
            #endif
            return localContainer
        } catch {
            #if DEBUG
            print("⚠️ Local container failed, trying in-memory: \(error)")
            #endif
            
            // Fallback to in-memory storage
            do {
                let memoryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                let memoryContainer = try ModelContainer(for: schema, configurations: memoryConfig)
                #if DEBUG
                print("⚠️ Using in-memory SwiftData container (data won't persist)")
                #endif
                return memoryContainer
            } catch {
                #if DEBUG
                print("❌ Critical: Even in-memory container failed: \(error)")
                #endif
                
                // This should never happen, but if it does, we need to know
                fatalError("Unable to initialize any SwiftData container. Error: \(error)")
            }
        }
    }()
}
