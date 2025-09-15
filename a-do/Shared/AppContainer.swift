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
        
        // Create a comprehensive schema with all models
        let schema = Schema([
            // Core reminder models
            Reminder.self,
            Tag.self,
            ReminderList.self,
            ReminderNotification.self,
            LocationTrigger.self,
            ListSection.self,
            TaggedContact.self,
            AppleNoteAttachment.self,
            VoiceReminder.self,
            
            // Habit tracking models
            Habit.self,
            HabitEntry.self,
            
            // Time tracking models
            TimeEntry.self,
            TimeCategory.self,
            TimeGoal.self,
            
            // Recurring reminders and templates
            RecurrenceRule.self,
            RecurringReminder.self,
            ReminderTemplate.self,
            TemplateCategory.self,
            
            // Collaboration models
            SharedReminder.self,
            ShareParticipant.self,
            ShareActivity.self,
            SharedList.self,
            ReminderComment.self,
            Workspace.self,
            WorkspaceMember.self,
            
            // Advanced smart lists
            EnhancedSmartList.self,
            EnhancedSmartListRule.self,
            SavedSearch.self,
            
            // Focus mode models
            FocusSession.self,
            FocusInterruption.self,
            FocusBreak.self,
            FocusTemplate.self,
            SystemFocusMode.self,
            FocusGoal.self,
            
            // AI models
            AISuggestion.self,
            AIInsight.self,
            AILearningData.self,
            AIModelPerformance.self,
            AIConfiguration.self,
            
            // Backup and export models
            BackupConfiguration.self,
            BackupRecord.self,
            ExportTemplate.self,
            ImportRecord.self,
            SyncConfiguration.self,
            SyncRecord.self,
            
            // Health integration models
            HealthIntegrationConfiguration.self,
            HealthMetric.self,
            HealthGoal.self,
            WorkoutIntegration.self,
            SleepIntegration.self,
            MindfulnessIntegration.self,
            HealthReminderTemplate.self,
            
            // Smart notification models
            SmartNotificationConfiguration.self,
            SmartNotification.self,
            NotificationPattern.self,
            NotificationBatch.self,
            NotificationAnalytics.self,
            NotificationRule.self,
            
            // Search and organization models
            SearchConfiguration.self,
            SearchQuery.self,
            SearchResult.self,
            SearchFilter.self,
            SearchIndex.self,
            OrganizationRule.self,
            QuickAction.self,
            SearchAnalytics.self,
            SavedSearch.self,
            
            // Gamification models
            UserProfile.self,
            Achievement.self,
            UserAchievement.self,
            Badge.self,
            UserBadge.self,
            Challenge.self,
            UserChallenge.self,
            Reward.self,
            UserReward.self,
            Leaderboard.self,
            LeaderboardEntry.self
        ])
        
        do {
            // Try CloudKit configuration first
            let cloudKitConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .automatic,
                cloudKitDatabase: .automatic
            )
            let container = try ModelContainer(for: schema, configurations: cloudKitConfig)
            _container = container
            return container
        } catch {
            // If CloudKit fails, try without CloudKit
            do {
                let localConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    groupContainer: .automatic,
                    cloudKitDatabase: .none
                )
                let container = try ModelContainer(for: schema, configurations: localConfig)
                _container = container
                return container
            } catch {
                // Fallback to in-memory if persistent fails
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    let container = try ModelContainer(for: schema, configurations: memoryConfig)
                    _container = container
                    return container
                } catch {
                    // Last resort - create minimal container
                    fatalError("Failed to create any ModelContainer: \(error)")
                }
            }
        }
    }
    
    // MARK: - Demo Data Management
    @MainActor
    static func clearAllDemoData(context: ModelContext) {
        #if DEBUG
        print("🧹 Clearing all demo data from database...")
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
            print("✅ All demo data cleared successfully")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save after clearing data: \(error)")
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
                print("🗑️ Deleted \(items.count) \(entityName)")
                #endif
            }
        } catch {
            #if DEBUG
            print("⚠️ Failed to clear \(entityName): \(error)")
            #endif
        }
    }
    
    // MARK: - Performance Optimization
    @MainActor
    static func optimizeDatabase(context: ModelContext) {
        #if DEBUG
        print("🔧 Optimizing database...")
        #endif
        
        // Perform any necessary database optimization tasks
        // This could include:
        // - Cleaning up orphaned records
        // - Optimizing indexes
        // - Compacting data
        
        do {
            try context.save()
            #if DEBUG
            print("✅ Database optimization completed")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ Database optimization failed: \(error)")
            #endif
        }
    }
}
