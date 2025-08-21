import Foundation
import SwiftData
import os

final class AppContainer {
    static let shared = AppContainer()
    
    private init() {}
    
    @MainActor
    lazy var container: ModelContainer = {
        return createContainer()
    }()
    
    @MainActor
    private func createContainer() -> ModelContainer {
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
        
        // Force clean start for simulator to avoid persistent issues
        #if targetEnvironment(simulator)
        return createInMemoryContainer(schema: schema)
        #else
        
        // Try to create persistent container on device
        do {
            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .automatic,
                cloudKitDatabase: .none,
                shouldDeleteOldDataOnModelMismatch: true
            )
            let localContainer = try ModelContainer(for: schema, configurations: localConfig)
            #if DEBUG
            print("✅ SwiftData local persistent container initialized")
            #endif
            return localContainer
        } catch {
            #if DEBUG
            print("⚠️ Local container failed: \(error)")
            print("🔄 Attempting complete database reset...")
            #endif
            
            // Clear all possible database files
            clearAllDatabaseFiles()
            
            // Try creating container again with fresh database
            do {
                let localConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    groupContainer: .automatic,
                    cloudKitDatabase: .none,
                    shouldDeleteOldDataOnModelMismatch: true
                )
                let localContainer = try ModelContainer(for: schema, configurations: localConfig)
                #if DEBUG
                print("✅ SwiftData container created with fresh database")
                #endif
                return localContainer
            } catch {
                #if DEBUG
                print("⚠️ Fresh database creation failed, falling back to in-memory: \(error)")
                #endif
                
                return createInMemoryContainer(schema: schema)
            }
        }
        #endif
    }
    
    @MainActor
    private func createInMemoryContainer(schema: Schema) -> ModelContainer {
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
    
    private func clearAllDatabaseFiles() {
        let fileManager = FileManager.default
        let urls = [
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        ].compactMap { $0 }
        
        let databaseNames = ["default.store", "default.store-wal", "default.store-shm"]
        
        for url in urls {
            for dbName in databaseNames {
                let dbURL = url.appendingPathComponent(dbName)
                try? fileManager.removeItem(at: dbURL)
            }
        }
        
        #if DEBUG
        print("🗑️ Cleared all database files from all directories")
        #endif
    }
}
