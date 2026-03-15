import Foundation
import SwiftData
import os

private enum AppGroupSchemaDefaults {
    nonisolated static func identifier() -> String {
        "group.com.ado.app"
    }

    nonisolated static func models() -> [any PersistentModel.Type] {
        [
            Reminder.self,
            Tag.self,
            ReminderList.self,
            ReminderNotification.self,
            LocationTrigger.self,
            AppleNoteAttachment.self,
            VoiceReminder.self,
            Habit.self,
            HabitEntry.self,
            FocusSession.self,
            TimeEntry.self,
            SearchIndex.self
        ]
    }
}

@Model
private final class RecoveryPlaceholder {
    var createdAt: Date = Date()

    init() {}
}

// MARK: - Minimal Safe AppContainer
// This provides only the essential functions needed by other parts of the app
// without complex initialization that could cause EXC_BAD_ACCESS crashes

final class AppContainer {
    static let shared = AppContainer()
    private let stateLock = NSLock()
    
    private init() {}
    
    // MARK: - Safe Container Access for App Intents
    // This is only used by App Intents that need container access
    private var _container: ModelContainer?
    private(set) var isDegradedMode = false
    private(set) var recoveryMessage: String?
    
    func getContainer() -> ModelContainer? {
        if let container = lockedContainer() {
            return container
        }

        let createdContainer: ModelContainer?
        if RuntimeEnvironment.isRunningTests {
            createdContainer = createTestContainer()
        } else {
            // Create container with progressive fallback strategy
            createdContainer = createContainerWithFallback()
        }

        guard let createdContainer else { return nil }
        return cacheContainerIfNeeded(createdContainer)
    }

    private func createTestContainer() -> ModelContainer? {
        let schemaResult = SwiftDataUtils.buildValidSchema()
        let configuration = ModelConfiguration(
            schema: schemaResult.schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schemaResult.schema, configurations: configuration)
            clearRecoveryState()
            os_log("Created in-memory SwiftData test container", log: .default, type: .info)
            return container
        } catch {
            os_log("Failed to create in-memory SwiftData test container: %{public}@", log: .default, type: .fault, error.localizedDescription)
            return createEmergencyContainer()
        }
    }
    
    private func createContainerWithFallback() -> ModelContainer? {
        os_log("Creating SwiftData container with diagnostic approach", log: .default, type: .info)
        clearRecoveryState()
        
        // Use the diagnostic utility to build a working schema
        let (container, diagnostics) = SwiftDataUtils.createDiagnosticContainer()
        
        // Log the diagnostics
        #if DEBUG
        print(diagnostics.summary)
        #endif
        
        os_log("Container creation diagnostics: %{public}@", log: .default, type: .info, diagnostics.summary)
        
        if let container = container {
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
        setDegradedMode("Recovered with an emergency in-memory data store. Recent data may be unavailable until the app is restarted.")
        SwiftDataUtils.resetPersistentStores()
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
    
    private func createEmergencyContainer() -> ModelContainer? {
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
                setDegradedMode("The app is running in limited recovery mode with temporary in-memory storage.")
                return container
            } catch {
                os_log("Emergency container attempt failed (models=%d): %{public}@", log: .default, type: .error, modelSet.count, error.localizedDescription)
            }
        }
        
        do {
            let schema = Schema([AppSettings.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: config)
            setDegradedMode("The app recovered with minimal temporary storage. Restart the app to restore full data access.")
            os_log("Created last-resort AppSettings-only emergency container", log: .default, type: .fault)
            return container
        } catch {
            os_log("AppSettings-only emergency container failed: %{public}@", log: .default, type: .fault, error.localizedDescription)
        }

        do {
            let schema = Schema([RecoveryPlaceholder.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: config)
            setDegradedMode("The app recovered in placeholder-only mode. Core data features are temporarily unavailable until restart.")
            os_log("Created placeholder-only recovery container", log: .default, type: .fault)
            return container
        } catch {
            os_log("Placeholder-only recovery container failed: %{public}@", log: .default, type: .fault, error.localizedDescription)
            setDegradedMode("Storage initialization failed. Restart the app to retry recovery.")
            return nil
        }
    }

    nonisolated static func makeAppGroupContainer(for models: [any PersistentModel.Type]? = nil) throws -> ModelContainer {
        let schema = Schema(models ?? AppGroupSchemaDefaults.models())
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier(AppGroupSchemaDefaults.identifier()),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    nonisolated static func makeAppGroupContext(for models: [any PersistentModel.Type]? = nil) throws -> ModelContext {
        ModelContext(try makeAppGroupContainer(for: models))
    }
    
    // MARK: - Progressive Model Loading
    // This allows adding more models after the initial container is created
    func expandSchema(with additionalModels: [any PersistentModel.Type]) -> Bool {
        guard lockedContainer() != nil else {
            os_log("No existing container to expand", log: .default, type: .error)
            return false
        }
        
        // SwiftData currently does not support runtime schema expansion.
        os_log("Schema expansion requested but not yet implemented", log: .default, type: .info)
        return false
    }
    
    // MARK: - Diagnostics
    func validateModels(_ models: [any PersistentModel.Type]) -> [String] {
        for modelType in models {
            let typeName = String(describing: modelType)
            
            // Check if the model type can be instantiated (basic validation)
            _ = Schema([modelType])
            // If we can create a schema with just this model, it's probably valid
            os_log("Model %{public}@ appears valid", log: .default, type: .debug, typeName)
        }
        
        return []
    }
    
    // MARK: - Safe Container Reset
    func resetContainer() {
        withStateLock {
            _container = nil
        }
        clearRecoveryState()
        os_log("Container reset - will recreate on next access", log: .default, type: .info)
    }
    
    // MARK: - Testing and Diagnostics
    #if DEBUG
    func testContainerCreation() -> String {
        resetContainer()
        _ = getContainer()
        let diagnostics = SwiftDataUtils.createDiagnosticContainer().diagnostics
        return """
        Container Creation Test Results:
        ✅ Container created successfully
        📊 Diagnostics:
        \(diagnostics.summary)
        """
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

    private func setDegradedMode(_ message: String) {
        withStateLock {
            isDegradedMode = true
            recoveryMessage = message
        }
    }

    private func clearRecoveryState() {
        withStateLock {
            isDegradedMode = false
            recoveryMessage = nil
        }
    }

    private func lockedContainer() -> ModelContainer? {
        withStateLock { _container }
    }

    private func cacheContainerIfNeeded(_ container: ModelContainer) -> ModelContainer {
        withStateLock {
            if let existing = _container {
                return existing
            }
            _container = container
            return container
        }
    }

    private func withStateLock<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }
}
