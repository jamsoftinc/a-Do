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
    /// Include ALL models referenced by Reminder relationships to avoid schema conflicts
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

        // Add models from TimeTrackingModels.swift
        let timeTrackingModels: [any PersistentModel.Type] = [
            TimeEntry.self,
            TimeCategory.self,
            TimeGoal.self
        ]
        extendedModels.append(contentsOf: timeTrackingModels)

        // Add habit models
        let habitModels: [any PersistentModel.Type] = [
            Habit.self,
            HabitEntry.self
        ]
        extendedModels.append(contentsOf: habitModels)

        // Add subscription models
        let subscriptionModels: [any PersistentModel.Type] = [
            SubscriptionStatus.self
        ]
        extendedModels.append(contentsOf: subscriptionModels)

        // Add Pro feature models (subtasks, dependencies, sketches)
        let proModels: [any PersistentModel.Type] = [
            Subtask.self,
            TaskDependency.self,
            Sketch.self
        ]
        extendedModels.append(contentsOf: proModels)

        // Add Focus Mode models (referenced by Reminder)
        let focusModels: [any PersistentModel.Type] = [
            FocusSession.self,
            FocusInterruption.self,
            FocusBreak.self,
            FocusTemplate.self,
            SystemFocusMode.self,
            FocusGoal.self
        ]
        extendedModels.append(contentsOf: focusModels)

        // Add Health models (referenced by Reminder)
        let healthModels: [any PersistentModel.Type] = [
            HealthIntegrationConfiguration.self,
            HealthMetric.self,
            HealthGoal.self,
            WorkoutIntegration.self,
            SleepIntegration.self,
            MindfulnessIntegration.self,
            HealthReminderTemplate.self
        ]
        extendedModels.append(contentsOf: healthModels)

        // Add Smart Notification models (referenced by Reminder)
        let notificationModels: [any PersistentModel.Type] = [
            SmartNotificationConfiguration.self,
            SmartNotification.self,
            NotificationPattern.self,
            NotificationBatch.self,
            NotificationAnalytics.self,
            NotificationRule.self
        ]
        extendedModels.append(contentsOf: notificationModels)

        // Add AI models (referenced by Reminder)
        let aiModels: [any PersistentModel.Type] = [
            AISuggestion.self,
            AIInsight.self,
            AILearningData.self,
            AIModelPerformance.self,
            AIConfiguration.self
        ]
        extendedModels.append(contentsOf: aiModels)

        // Add Collaboration models (referenced by Reminder and ReminderList)
        let collaborationModels: [any PersistentModel.Type] = [
            SharedReminder.self,
            ShareParticipant.self,
            ShareActivity.self,
            SharedList.self,
            ReminderComment.self,
            Workspace.self,
            WorkspaceMember.self
        ]
        extendedModels.append(contentsOf: collaborationModels)

        // Add Recurring models (referenced by Reminder)
        let recurringModels: [any PersistentModel.Type] = [
            RecurrenceRule.self,
            RecurringReminder.self,
            ReminderTemplate.self,
            TemplateCategory.self
        ]
        extendedModels.append(contentsOf: recurringModels)

        // Add Backup models
        let backupModels: [any PersistentModel.Type] = [
            BackupConfiguration.self,
            BackupRecord.self,
            ExportTemplate.self,
            ImportRecord.self,
            SyncConfiguration.self,
            SyncRecord.self
        ]
        extendedModels.append(contentsOf: backupModels)

        // Add Search models
        let searchModels: [any PersistentModel.Type] = [
            SearchConfiguration.self,
            SearchQuery.self,
            SearchResult.self,
            SearchFilter.self,
            SearchIndex.self,
            OrganizationRule.self,
            QuickAction.self,
            SearchAnalytics.self
        ]
        extendedModels.append(contentsOf: searchModels)

        // Add Advanced Smart List models
        let smartListModels: [any PersistentModel.Type] = [
            EnhancedSmartListRule.self,
            EnhancedSmartList.self,
            SavedSearch.self
        ]
        extendedModels.append(contentsOf: smartListModels)

        // Add Gamification models (simplified - no leaderboards)
        let gamificationModels: [any PersistentModel.Type] = [
            UserProfile.self,
            Achievement.self,
            UserAchievement.self,
            Badge.self,
            UserBadge.self,
            Challenge.self,
            UserChallenge.self,
            Reward.self,
            UserReward.self
        ]
        extendedModels.append(contentsOf: gamificationModels)

        return extendedModels
    }
    
    // MARK: - Schema Building

    /// Get ALL model types that need to be in the schema together
    /// IMPORTANT: Models with @Relationship MUST be included together, not validated individually
    static func getAllModelTypes() -> [any PersistentModel.Type] {
        var allModels: [any PersistentModel.Type] = []

        // Core models
        allModels.append(contentsOf: getCoreModelTypes())

        // Extended models
        allModels.append(contentsOf: getExtendedModelTypes())

        return allModels
    }

    /// Build schema with ALL models at once
    /// Individual validation breaks models with @Relationship attributes
    static func buildValidSchema() -> (schema: Schema, successfulModels: [String], failedModels: [String]) {
        let allModels = getAllModelTypes()
        let modelNames = allModels.map { String(describing: $0) }

        // Create schema with ALL models together - don't validate individually
        // Models with @Relationship attributes REQUIRE all related models to be present
        let schema = Schema(allModels)

        logger.info("Built schema with \(allModels.count, privacy: .public) models (no individual validation - relationships require all models together)")

        return (schema, modelNames, [])
    }
    
    // MARK: - Container Creation with Diagnostics

    static func createDiagnosticContainer() -> (container: ModelContainer?, diagnostics: ContainerDiagnostics) {
        let schemaResult = buildValidSchema()
        let schema = schemaResult.schema

        var diagnostics = ContainerDiagnostics(
            successfulModels: schemaResult.successfulModels,
            failedModels: schemaResult.failedModels
        )

        // Try persistent storage first with explicit app group
        do {
            let persistentConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .identifier("group.com.ado.app"),
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: persistentConfig)
            diagnostics.containerType = .persistent
            logger.info("Created persistent container successfully with app group")
            return (container, diagnostics)
        } catch {
            diagnostics.persistentStorageError = error.localizedDescription
            logger.error("Persistent container with app group failed: \(error.localizedDescription, privacy: .public)")
        }

        // Try persistent storage without app group as fallback
        do {
            let persistentConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: persistentConfig)
            diagnostics.containerType = .persistent
            logger.info("Created persistent container successfully without app group")
            return (container, diagnostics)
        } catch {
            diagnostics.persistentStorageError = (diagnostics.persistentStorageError ?? "") + " | Without group: " + error.localizedDescription
            logger.error("Persistent container without app group failed: \(error.localizedDescription, privacy: .public)")
        }

        // Try in-memory storage as last fallback
        do {
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: memoryConfig)
            diagnostics.containerType = .memory
            logger.warning("Created in-memory container - DATA WILL NOT PERSIST")
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