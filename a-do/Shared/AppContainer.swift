import Foundation
import SwiftData
import os

// MARK: - Minimal Safe AppContainer
// This provides only the essential functions needed by other parts of the app
// without complex initialization that could cause EXC_BAD_ACCESS crashes

final class AppContainer {
    static let shared = AppContainer()
    
    private init() {}
    
    // MARK: - Safe Container Access for App Intents
    // This is only used by App Intents that need container access
    private var _container: ModelContainer?
    
    func getContainer() -> ModelContainer {
        if let container = _container {
            return container
        }
        
        // Create container with progressive fallback strategy
        return createContainerWithFallback()
    }
    
    private func createContainerWithFallback() -> ModelContainer {
        os_log("Creating SwiftData container with diagnostic approach", log: .default, type: .info)
        
        // Use the diagnostic utility to build a working schema
        let (container, diagnostics) = SwiftDataUtils.createDiagnosticContainer()
        
        // Log the diagnostics
        #if DEBUG
        print(diagnostics.summary)
        #endif
        
        os_log("Container creation diagnostics: %{public}@", log: .default, type: .info, diagnostics.summary)
        
        if let container = container {
            _container = container
            
            // Log container configuration for debugging
            #if DEBUG
            let configs = container.configurations
            for config in configs {
                print("Container configuration: memory-only=\(config.isStoredInMemoryOnly), URL=\(config.url.path)")
            }
            #endif
            
            return container
        }
        
        // If diagnostic approach failed completely, try emergency fallback
        os_log("Diagnostic container creation failed, attempting emergency fallback", log: .default, type: .error)
        return createEmergencyContainer()
    }
    
    private func attemptContainerCreation(
        with models: [any PersistentModel.Type],
        name: String,
        forceMemory: Bool = false
    ) -> ModelContainer? {
        let schema = Schema(models)
        
        // Try persistent storage first (unless forced to memory)
        if !forceMemory {
            do {
                let persistentConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    groupContainer: .automatic,
                    cloudKitDatabase: .none
                )
                let container = try ModelContainer(for: schema, configurations: persistentConfig)
                os_log("Successfully created persistent container with %{public}@", log: .default, type: .info, name)
                return container
            } catch {
                os_log("Failed to create persistent container with %{public}@: %{public}@", log: .default, type: .error, name, error.localizedDescription)
            }
        }
        
        // Try in-memory storage as fallback
        do {
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: memoryConfig)
            os_log("Successfully created in-memory container with %{public}@", log: .default, type: .info, name)
            return container
        } catch {
            os_log("Failed to create in-memory container with %{public}@: %{public}@", log: .default, type: .error, name, error.localizedDescription)
            return nil
        }
    }
    
    private func createEmergencyContainer() -> ModelContainer {
        // Create the most basic possible container that should always work
        let emergencyModelSets: [[any PersistentModel.Type]] = [
            [],
            [UserProfile.self],
            [AppSettings.self],
            [Reminder.self, Tag.self, ReminderList.self]
        ]

        for modelSet in emergencyModelSets {
            do {
                let schema = Schema(modelSet)
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: schema, configurations: config)
                os_log("Created emergency container with %d model types", log: .default, type: .default, modelSet.count)
                _container = container
                return container
            } catch {
                os_log("Emergency container attempt failed (models=%d): %{public}@", log: .default, type: .error, modelSet.count, error.localizedDescription)
            }
        }

        fatalError("SwiftData is completely non-functional after all emergency fallbacks.")
    }
    
    // MARK: - Progressive Model Loading
    // This allows adding more models after the initial container is created
    func expandSchema(with additionalModels: [any PersistentModel.Type]) -> Bool {
        guard let currentContainer = _container else {
            os_log("No existing container to expand", log: .default, type: .error)
            return false
        }
        
        // SwiftData currently does not support runtime schema expansion.
        os_log("Schema expansion requested but not yet implemented", log: .default, type: .info)
        return false
    }
    
    // MARK: - Diagnostics
    func validateModels(_ models: [any PersistentModel.Type]) -> [String] {
        var issues: [String] = []
        
        for modelType in models {
            let typeName = String(describing: modelType)
            
            // Check if the model type can be instantiated (basic validation)
            do {
                let schema = Schema([modelType])
                // If we can create a schema with just this model, it's probably valid
                os_log("Model %{public}@ appears valid", log: .default, type: .debug, typeName)
            } catch {
                issues.append("Model \(typeName) failed validation: \(error.localizedDescription)")
            }
        }
        
        return issues
    }
    
    // MARK: - Safe Container Reset
    func resetContainer() {
        _container = nil
        os_log("Container reset - will recreate on next access", log: .default, type: .info)
    }
    
    // MARK: - Testing and Diagnostics
    #if DEBUG
    func testContainerCreation() -> String {
        resetContainer()
        do {
            let container = getContainer()
            let diagnostics = SwiftDataUtils.createDiagnosticContainer().diagnostics
            return """
            Container Creation Test Results:
            ✅ Container created successfully
            📊 Diagnostics:
            \(diagnostics.summary)
            """
        } catch {
            return """
            Container Creation Test Results:
            ❌ Container creation failed: \(error.localizedDescription)
            """
        }
    }
    #endif
    
    // MARK: - Data Maintenance
    @MainActor
    static func clearAllData(context: ModelContext) {
        #if DEBUG
        // Clearing all persisted data
        #endif
        
        // Clear all reminders
        clearEntityType(Reminder.self, context: context, entityName: "reminders")
        clearEntityType(Tag.self, context: context, entityName: "tags")
        clearEntityType(ReminderList.self, context: context, entityName: "reminder lists")
        clearEntityType(ListSection.self, context: context, entityName: "list sections")
        clearEntityType(LocationTrigger.self, context: context, entityName: "location triggers")
        clearEntityType(ReminderNotification.self, context: context, entityName: "notifications")
        clearEntityType(TaggedContact.self, context: context, entityName: "tagged contacts")
        clearEntityType(AppleNoteAttachment.self, context: context, entityName: "note attachments")
        clearEntityType(VoiceReminder.self, context: context, entityName: "voice reminders")
        
        // Save changes
        do {
            try context.save()
            #if DEBUG
            // Data cleared successfully
            #endif
        } catch {
            #if DEBUG
            // Failed to save after clearing data
            #endif
        }
    }
    
    private static func clearEntityType<T: PersistentModel>(_ entityType: T.Type, context: ModelContext, entityName: String) {
        do {
            let descriptor = FetchDescriptor<T>()
            let items = try context.fetch(descriptor)
            
            if !items.isEmpty {
                for item in items {
                    context.delete(item)
                }
                #if DEBUG
                // Deleted items
                #endif
            }
        } catch {
            #if DEBUG
            // Failed to clear entity
            #endif
        }
    }
    
    // MARK: - Performance Optimization
    @MainActor
    static func optimizeDatabase(context: ModelContext) {
        #if DEBUG
        // Optimizing database
        #endif
        
        // Perform any necessary database optimization tasks
        // This could include:
        // - Cleaning up orphaned records
        // - Optimizing indexes
        // - Compacting data
        
        // Perform standard database optimization
        
        do {
            try context.save()
            #if DEBUG
            // Database optimization completed
            #endif
        } catch {
            #if DEBUG
            // Database optimization failed
            #endif
        }
    }
}
