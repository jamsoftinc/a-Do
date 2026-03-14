//
//  MemoryOptimization.swift
//  a-do
//
//  Memory optimization utilities to prevent EXC_RESOURCE crashes
//

import Foundation
import SwiftData
import os
import UIKit

struct SearchableReminderSnapshot: Identifiable, Sendable {
    let id: String
    let title: String
    let details: String
    let tags: [String]
    let isCompleted: Bool
    let isOverdue: Bool
    let priority: Priority
    let dueDate: Date?
    let createdAt: Date
    let estimatedDurationMinutes: Int
}

struct SearchableHabitSnapshot: Identifiable, Sendable {
    let id: String
    let title: String
    let details: String
}

// MARK: - Memory Monitor

@MainActor
final class MemoryMonitor {
    static let shared = MemoryMonitor()
    
    private let logger = Logger(subsystem: "a-do", category: "Memory")
    private var memoryWarningObserver: NSObjectProtocol?
    
    private init() {
        setupMemoryWarningObserver()
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleMemoryWarning()
            }
        }
    }
    
    private func handleMemoryWarning() {
        logger.warning("Memory warning received - clearing caches and optimizing memory")
        
        // Clear various caches
        clearCaches()
        
        // Force garbage collection
        autoreleasepool {
            // This helps release temporary objects
        }
    }
    
    private func clearCaches() {
        // Clear smart list caches
        AdvancedSmartListManager.shared.clearCache()
        
        logger.info("Caches cleared due to memory warning")
    }
    
    func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    func logMemoryUsage() {
        let memoryUsage = getCurrentMemoryUsage()
        let memoryMB = Double(memoryUsage) / 1024.0 / 1024.0
        logger.info("Current memory usage: \(String(format: "%.1f", memoryMB)) MB")
    }
}

// MARK: - Memory-Safe Data Loading

struct MemorySafeDataLoader {
    static func loadReminders(
        context: ModelContext,
        limit: Int = 100,
        predicate: Predicate<Reminder>? = nil
    ) async -> [PersistentIdentifier] {
        return await Task.detached {
            let backgroundContext = ModelContext(context.container)
            var descriptor = FetchDescriptor<Reminder>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            // Include pending changes to show newly created reminders
            descriptor.includePendingChanges = true
            
            do {
                let reminders = try backgroundContext.fetch(descriptor)
                return reminders.map { $0.persistentModelID }
            } catch {
                return []
            }
        }.value
    }
    
    static func loadLists(
        context: ModelContext,
        limit: Int = 50
    ) async -> [PersistentIdentifier] {
        return await Task.detached {
            let backgroundContext = ModelContext(context.container)
            var descriptor = FetchDescriptor<ReminderList>()
            descriptor.fetchLimit = limit
            
            do {
                let lists = try backgroundContext.fetch(descriptor)
                return lists.map { $0.persistentModelID }
            } catch {
                return []
            }
        }.value
    }
    
    static func loadHabits(
        context: ModelContext,
        limit: Int = 50
    ) async -> [PersistentIdentifier] {
        return await Task.detached {
            let backgroundContext = ModelContext(context.container)
            var descriptor = FetchDescriptor<Habit>()
            descriptor.fetchLimit = limit
            
            do {
                let habits = try backgroundContext.fetch(descriptor)
                return habits.map { $0.persistentModelID }
            } catch {
                return []
            }
        }.value
    }
    
    static func loadTimeEntries(
        context: ModelContext,
        limit: Int = 100
    ) async -> [PersistentIdentifier] {
        return await Task.detached {
            let backgroundContext = ModelContext(context.container)
            var descriptor = FetchDescriptor<TimeEntry>()
            descriptor.fetchLimit = limit
            
            do {
                let entries = try backgroundContext.fetch(descriptor)
                return entries.map { $0.persistentModelID }
            } catch {
                return []
            }
        }.value
    }
    
    static func loadSharedReminders(
        context: ModelContext,
        limit: Int = 100
    ) async -> [PersistentIdentifier] {
        return await Task.detached {
            let backgroundContext = ModelContext(context.container)
            var descriptor = FetchDescriptor<SharedReminder>()
            descriptor.fetchLimit = limit
            
            do {
                let shared = try backgroundContext.fetch(descriptor)
                return shared.map { $0.persistentModelID }
            } catch {
                return []
            }
        }.value
    }

    static func loadSearchableReminders(
        context: ModelContext,
        limit: Int = 1000
    ) async -> [SearchableReminderSnapshot] {
        return await Task.detached {
            let backgroundContext = ModelContext(context.container)
            var descriptor = FetchDescriptor<Reminder>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = limit

            do {
                let reminders = try backgroundContext.fetch(descriptor)
                return reminders.map { reminder in
                    SearchableReminderSnapshot(
                        id: reminder.uuid.uuidString,
                        title: reminder.title,
                        details: reminder.details ?? "",
                        tags: reminder.tags?.map(\.name) ?? [],
                        isCompleted: reminder.isCompleted,
                        isOverdue: reminder.isOverdue,
                        priority: reminder.priority,
                        dueDate: reminder.dueDate,
                        createdAt: reminder.createdAt,
                        estimatedDurationMinutes: estimatedDurationMinutes(for: reminder)
                    )
                }
            } catch {
                return []
            }
        }.value
    }

    static func loadSearchableHabits(
        context: ModelContext,
        limit: Int = 500
    ) async -> [SearchableHabitSnapshot] {
        return await Task.detached {
            let backgroundContext = ModelContext(context.container)
            var descriptor = FetchDescriptor<Habit>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            descriptor.fetchLimit = limit

            do {
                let habits = try backgroundContext.fetch(descriptor)
                return habits.map { habit in
                    SearchableHabitSnapshot(
                        id: habit.id.uuidString,
                        title: habit.title,
                        details: habit.habitDescription
                    )
                }
            } catch {
                return []
            }
        }.value
    }

    private static func estimatedDurationMinutes(for reminder: Reminder) -> Int {
        let detailLength = (reminder.details ?? "").count
        let titleLength = reminder.title.count
        let subtaskCount = reminder.subtasks?.count ?? 0
        let complexityEstimate = max(10, min(120, (titleLength / 2) + (detailLength / 8)))
        return max(complexityEstimate, subtaskCount > 0 ? subtaskCount * 15 : 0)
    }
}
