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
            self?.handleMemoryWarning()
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
    ) async -> [Reminder] {
        return await Task.detached {
            let backgroundContext = ModelContext(context.container)
            var descriptor = FetchDescriptor<Reminder>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            return (try? backgroundContext.fetch(descriptor)) ?? []
        }.value
    }
    
    static func loadLists(
        context: ModelContext,
        limit: Int = 50
    ) async -> [ReminderList] {
        return await Task.detached {
            let backgroundContext = ModelContext(context.container)
            var descriptor = FetchDescriptor<ReminderList>()
            descriptor.fetchLimit = limit
            return (try? backgroundContext.fetch(descriptor)) ?? []
        }.value
    }
    
    static func loadHabits(
        context: ModelContext,
        limit: Int = 50
    ) async -> [Habit] {
        return await Task.detached {
            let backgroundContext = ModelContext(context.container)
            var descriptor = FetchDescriptor<Habit>()
            descriptor.fetchLimit = limit
            return (try? backgroundContext.fetch(descriptor)) ?? []
        }.value
    }
    
    static func loadTimeEntries(
        context: ModelContext,
        limit: Int = 100
    ) async -> [TimeEntry] {
        return await Task.detached {
            let backgroundContext = ModelContext(context.container)
            var descriptor = FetchDescriptor<TimeEntry>()
            descriptor.fetchLimit = limit
            return (try? backgroundContext.fetch(descriptor)) ?? []
        }.value
    }
    
    static func loadSharedReminders(
        context: ModelContext,
        limit: Int = 100
    ) async -> [SharedReminder] {
        return await Task.detached {
            let backgroundContext = ModelContext(context.container)
            var descriptor = FetchDescriptor<SharedReminder>()
            descriptor.fetchLimit = limit
            return (try? backgroundContext.fetch(descriptor)) ?? []
        }.value
    }
}