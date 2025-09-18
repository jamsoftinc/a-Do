import Foundation
import SwiftData
import os

// MARK: - SwiftData Utilities
// Helper utilities for debugging and managing SwiftData issues

struct SwiftDataUtils {
    static let logger = Logger(subsystem: "com.yourapp.swiftdata", category: "utils")
    
    // MARK: - Model Validation
    
    /// Validate a single model type to see if it can be used in a schema
    static func validateModelType(_ modelType: any PersistentModel.Type) -> ValidationResult {
        let typeName = String(describing: modelType)
        
        do {
            let schema = Schema([modelType])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: config)
            
            // If we got here, the model is valid
            logger.info("✅ Model \(typeName, privacy: .public) validated successfully")
            return .success
        } catch {
            logger.error("❌ Model \(typeName, privacy: .public) validation failed: \(error.localizedDescription, privacy: .public)")
            return .failure(error)
        }
    }
    
    /// Validate multiple model types and find which ones are problematic
    static func validateModelTypes(_ modelTypes: [any PersistentModel.Type]) -> [String: ValidationResult] {
        var results: [String: ValidationResult] = [:]
        
        for modelType in modelTypes {
            let typeName = String(describing: modelType)
            results[typeName] = validateModelType(modelType)
        }
        
        return results
    }
    
    /// Get a list of core models that should always work
    static func getCoreModelTypes() -> [any PersistentModel.Type] {
        return [
            Reminder.self,
            Tag.self,
            ReminderList.self,
            AppSettings.self
        ]
    }
    
    /// Get a list of extended models (may have dependencies)
    /// Only include models we know exist based on the files we've seen
    static func getExtendedModelTypes() -> [any PersistentModel.Type] {
        var extendedModels: [any PersistentModel.Type] = []
        
        // Add models we know exist from ReminderModels.swift
        let reminderModels: [any PersistentModel.Type] = [
            ReminderNotification.self,
            LocationTrigger.self,
            ListSection.self,
            TaggedContact.self,
            AppleNoteAttachment.self,
            VoiceReminder.self
        ]
        extendedModels.append(contentsOf: reminderModels)
        
        // Add models from TimeTrackingModels.swift that we've confirmed exist
        let timeTrackingModels: [any PersistentModel.Type] = [
            TimeEntry.self,
            TimeCategory.self
        ]
        extendedModels.append(contentsOf: timeTrackingModels)
        
        // Add habit models
        let habitModels: [any PersistentModel.Type] = [
            Habit.self,
            HabitEntry.self
        ]
        extendedModels.append(contentsOf: habitModels)
        
        // Note: We're not including models that might not exist yet like:
        // RecurrenceRule, etc. These can be added later when they're properly defined
        
        return extendedModels
    }
    
    // MARK: - Progressive Schema Building
    
    /// Build a schema progressively, starting with core models and adding others that validate
    static func buildValidSchema() -> (schema: Schema, successfulModels: [String], failedModels: [String]) {
        var successfulModels: [String] = []
        var failedModels: [String] = []
        var validModelTypes: [any PersistentModel.Type] = []
        
        // Start with core models
        let coreModels = getCoreModelTypes()
        for modelType in coreModels {
            let typeName = String(describing: modelType)
            if case .success = validateModelType(modelType) {
                validModelTypes.append(modelType)
                successfulModels.append(typeName)
            } else {
                failedModels.append(typeName)
            }
        }
        
        // Try extended models
        let extendedModels = getExtendedModelTypes()
        for modelType in extendedModels {
            let typeName = String(describing: modelType)
            
            // Test if adding this model to our current set would work
            let testModelTypes = validModelTypes + [modelType]
            let testSchema = Schema(testModelTypes)
            
            do {
                let testConfig = ModelConfiguration(schema: testSchema, isStoredInMemoryOnly: true)
                let _ = try ModelContainer(for: testSchema, configurations: testConfig)
                
                // If we got here, adding this model is safe
                validModelTypes.append(modelType)
                successfulModels.append(typeName)
            } catch {
                failedModels.append("\(typeName): \(error.localizedDescription)")
                logger.error("Model \(typeName, privacy: .public) cannot be added to schema: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        let finalSchema = Schema(validModelTypes)
        logger.info("Built schema with \(successfulModels.count, privacy: .public) successful models, \(failedModels.count, privacy: .public) failed models")
        
        return (finalSchema, successfulModels, failedModels)
    }
    
    // MARK: - Container Creation with Diagnostics
    
    static func createDiagnosticContainer() -> (container: ModelContainer?, diagnostics: ContainerDiagnostics) {
        let schemaResult = buildValidSchema()
        let schema = schemaResult.schema
        
        var diagnostics = ContainerDiagnostics(
            successfulModels: schemaResult.successfulModels,
            failedModels: schemaResult.failedModels
        )
        
        // Try persistent storage first
        do {
            let persistentConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .automatic,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: persistentConfig)
            diagnostics.containerType = .persistent
            logger.info("Created persistent container successfully")
            return (container, diagnostics)
        } catch {
            diagnostics.persistentStorageError = error.localizedDescription
            logger.error("Persistent container failed: \(error.localizedDescription, privacy: .public)")
        }
        
        // Try in-memory storage as fallback
        do {
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: memoryConfig)
            diagnostics.containerType = .memory
            logger.info("Created in-memory container successfully")
            return (container, diagnostics)
        } catch {
            diagnostics.memoryStorageError = error.localizedDescription
            logger.error("In-memory container failed: \(error.localizedDescription, privacy: .public)")
        }
        
        // If we get here, even basic models are failing
        diagnostics.containerType = .failed
        return (nil, diagnostics)
    }
}

// MARK: - Supporting Types

enum ValidationResult {
    case success
    case failure(Error)
}

struct ContainerDiagnostics {
    var successfulModels: [String] = []
    var failedModels: [String] = []
    var containerType: ContainerType = .unknown
    var persistentStorageError: String?
    var memoryStorageError: String?
    
    enum ContainerType {
        case unknown
        case persistent
        case memory
        case failed
    }
    
    var summary: String {
        var lines: [String] = []
        lines.append("SwiftData Container Diagnostics:")
        lines.append("- Successful models: \(successfulModels.count)")
        lines.append("- Failed models: \(failedModels.count)")
        lines.append("- Container type: \(containerType)")
        
        if !failedModels.isEmpty {
            lines.append("Failed models:")
            for model in failedModels {
                lines.append("  • \(model)")
            }
        }
        
        if let error = persistentStorageError {
            lines.append("Persistent storage error: \(error)")
        }
        
        if let error = memoryStorageError {
            lines.append("Memory storage error: \(error)")
        }
        
        return lines.joined(separator: "\n")
    }
}