import Foundation
import SwiftData
import os

@MainActor
@Observable
final class ReminderCleanupManager {
    static let shared = ReminderCleanupManager()
    
    private let logger = Logger(subsystem: "a-do", category: "Cleanup")
    private var cleanupTimer: Timer?
    
    private init() {
        setupPeriodicCleanup()
    }
    
    // MARK: - Setup
    
    func setupPeriodicCleanup() {
        // Disable automatic cleanup to prevent SwiftData errors
        // Cleanup should be triggered manually from views with proper context
        logger.info("Periodic cleanup disabled - use manual cleanup from views")
    }
    
    // MARK: - Cleanup Logic
    
    func performCleanup() async {
        logger.info("Starting reminder cleanup")
        
        // Get the main app context from AppContainer
        guard let context = await getMainAppContext() else {
            logger.info("Main app context not available - skipping automatic cleanup")
            return
        }
        
        await cleanupOldReminders(in: context)
    }
    
    private func getMainAppContext() async -> ModelContext? {
        // Don't try to create a context here - it should be passed from the calling view
        return nil
    }
    
    // MARK: - Manual Cleanup
    
    func cleanupOldReminders(in context: ModelContext) async {
        logger.info("Performing manual cleanup")
        
        do {
            // Calculate the cutoff date (30 days ago)
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            
            let descriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate<Reminder> { reminder in
                    reminder.isCompleted == true &&
                    reminder.completedAt != nil &&
                    reminder.completedAt! < thirtyDaysAgo
                }
            )
            
            let oldCompletedReminders = try context.fetch(descriptor)
            
            if !oldCompletedReminders.isEmpty {
                logger.info("Found \(oldCompletedReminders.count) completed reminders older than 30 days")
                
                for reminder in oldCompletedReminders {
                    context.delete(reminder)
                    logger.info("Deleted old completed reminder: '\(reminder.title)'")
                }
                
                try context.save()
                logger.info("Successfully cleaned up \(oldCompletedReminders.count) old reminders")
            }
        } catch {
            logger.error("Manual cleanup failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup
    
    func stopCleanupTimer() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
}
