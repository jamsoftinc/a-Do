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
                cloudKitDatabase: .none
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
                    cloudKitDatabase: .none
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
    
    // MARK: - Demo Data Management
    
    @MainActor
    static func clearAllDemoData(context: ModelContext) {
        #if DEBUG
        print("🧹 Clearing all demo data from database...")
        #endif
        
        // Clear all reminders
        let reminderDescriptor = FetchDescriptor<Reminder>()
        if let reminders = try? context.fetch(reminderDescriptor) {
            for reminder in reminders {
                context.delete(reminder)
            }
            #if DEBUG
            print("🗑️ Deleted \(reminders.count) reminders")
            #endif
        }
        
        // Clear all tags
        let tagDescriptor = FetchDescriptor<Tag>()
        if let tags = try? context.fetch(tagDescriptor) {
            for tag in tags {
                context.delete(tag)
            }
            #if DEBUG
            print("🗑️ Deleted \(tags.count) tags")
            #endif
        }
        
        // Clear all reminder lists
        let listDescriptor = FetchDescriptor<ReminderList>()
        if let lists = try? context.fetch(listDescriptor) {
            for list in lists {
                context.delete(list)
            }
            #if DEBUG
            print("🗑️ Deleted \(lists.count) reminder lists")
            #endif
        }
        
        // Clear all list sections
        let sectionDescriptor = FetchDescriptor<ListSection>()
        if let sections = try? context.fetch(sectionDescriptor) {
            for section in sections {
                context.delete(section)
            }
            #if DEBUG
            print("🗑️ Deleted \(sections.count) list sections")
            #endif
        }
        
        // Clear all location triggers
        let locationDescriptor = FetchDescriptor<LocationTrigger>()
        if let locations = try? context.fetch(locationDescriptor) {
            for location in locations {
                context.delete(location)
            }
            #if DEBUG
            print("🗑️ Deleted \(locations.count) location triggers")
            #endif
        }
        
        // Clear all notifications
        let notificationDescriptor = FetchDescriptor<ReminderNotification>()
        if let notifications = try? context.fetch(notificationDescriptor) {
            for notification in notifications {
                context.delete(notification)
            }
            #if DEBUG
            print("🗑️ Deleted \(notifications.count) notifications")
            #endif
        }
        
        // Clear all tagged contacts
        let contactDescriptor = FetchDescriptor<TaggedContact>()
        if let contacts = try? context.fetch(contactDescriptor) {
            for contact in contacts {
                context.delete(contact)
            }
            #if DEBUG
            print("🗑️ Deleted \(contacts.count) tagged contacts")
            #endif
        }
        
        // Clear all note attachments
        let noteDescriptor = FetchDescriptor<AppleNoteAttachment>()
        if let notes = try? context.fetch(noteDescriptor) {
            for note in notes {
                context.delete(note)
            }
            #if DEBUG
            print("🗑️ Deleted \(notes.count) note attachments")
            #endif
        }
        
        // Save changes
        do {
            try context.save()
            #if DEBUG
            print("✅ All demo data cleared successfully")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save after clearing demo data: \(error)")
            #endif
        }
    }
}
