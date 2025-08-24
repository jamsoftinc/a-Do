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
    
    private func setupPeriodicCleanup() {
        // Run cleanup every hour
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performCleanup()
            }
        }
        
        // Also run cleanup immediately when app starts
        Task {
            await performCleanup()
        }
    }
    
    // MARK: - Cleanup Logic
    
    func performCleanup() async {
        logger.info("Starting reminder cleanup")
        
        guard let context = try? ModelContext(ModelContainer(for: Reminder.self)) else {
            logger.error("Failed to create model context for cleanup")
            return
        }
        
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
            } else {
                logger.info("No old completed reminders found")
            }
        } catch {
            logger.error("Cleanup failed: \(error.localizedDescription)")
        }
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
