//
//  SubtasksManager.swift
//  a-do
//
//  Subtasks and Dependencies Manager for Pro users
//

import Foundation
import SwiftData
import Observation
import os

@MainActor
@Observable
final class SubtasksManager {
    static let shared = SubtasksManager()
    
    private let logger = Logger(subsystem: "a-do", category: "Subtasks")
    
    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.canUseSubtasks
    }
    
    private init() {}
    
    // MARK: - Subtask Management
    
    func addSubtask(to parent: Reminder, title: String, context: ModelContext) -> Subtask? {
        guard isProEnabled else {
            logger.warning("Subtasks is a Pro feature")
            return nil
        }
        
        logger.info("Adding subtask '\(title)' to '\(parent.title)'")
        
        let subtask = Subtask(title: title, parentReminder: parent)
        context.insert(subtask)
        
        do {
            try context.save()
            logger.info("Subtask added successfully")
            return subtask
        } catch {
            logger.error("Failed to add subtask: \(error.localizedDescription)")
            return nil
        }
    }
    
    func removeSubtask(_ subtask: Subtask, context: ModelContext) {
        guard isProEnabled else {
            logger.warning("Subtasks is a Pro feature")
            return
        }
        
        logger.info("Removing subtask '\(subtask.title)'")
        
        context.delete(subtask)
        
        do {
            try context.save()
            logger.info("Subtask removed successfully")
        } catch {
            logger.error("Failed to remove subtask: \(error.localizedDescription)")
        }
    }
    
    func completeSubtask(_ subtask: Subtask, context: ModelContext) {
        guard isProEnabled else {
            logger.warning("Subtasks is a Pro feature")
            return
        }
        
        logger.info("Completing subtask '\(subtask.title)'")
        
        subtask.isCompleted = true
        subtask.completedAt = Date()
        
        do {
            try context.save()
            
            // Check if all subtasks are complete
            if let parent = subtask.parentReminder {
                checkAndCompleteParentIfNeeded(parent, context: context)
            }
            
            logger.info("Subtask completed successfully")
        } catch {
            logger.error("Failed to complete subtask: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Dependency Management
    
    func addDependency(from task: Reminder, to dependsOn: Reminder, context: ModelContext) -> TaskDependency? {
        guard isProEnabled else {
            logger.warning("Subtasks is a Pro feature")
            return nil
        }
        
        logger.info("Adding dependency from '\(task.title)' to '\(dependsOn.title)'")
        
        // Check for circular dependencies
        if hasCircularDependency(startingFrom: dependsOn, searchingFor: task, context: context) {
            logger.error("Circular dependency detected")
            return nil
        }
        
        let dependency = TaskDependency(blockingTask: dependsOn, blockedTask: task)
        context.insert(dependency)
        
        do {
            try context.save()
            logger.info("Dependency added successfully")
            return dependency
        } catch {
            logger.error("Failed to add dependency: \(error.localizedDescription)")
            return nil
        }
    }
    
    func canStartTask(_ task: Reminder, context: ModelContext) -> Bool {
        guard isProEnabled else { return true }

        // Check if all dependencies are complete
        let taskUUID = task.uuid
        let descriptor = FetchDescriptor<TaskDependency>(
            predicate: #Predicate<TaskDependency> { $0.blockedTask?.uuid == taskUUID }
        )
        
        guard let dependencies = try? context.fetch(descriptor) else {
            return true
        }
        
        for dependency in dependencies {
            if let blockingTask = dependency.blockingTask, !blockingTask.isCompleted {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Helper Methods
    
    private func checkAndCompleteParentIfNeeded(_ parent: Reminder, context: ModelContext) {
        let parentUUID = parent.uuid
        let descriptor = FetchDescriptor<Subtask>(
            predicate: #Predicate<Subtask> { $0.parentReminder?.uuid == parentUUID }
        )
        
        guard let subtasks = try? context.fetch(descriptor) else { return }
        
        let allCompleted = subtasks.allSatisfy { $0.isCompleted }
        
        if allCompleted {
            logger.info("All subtasks complete, completing parent reminder")
            parent.isCompleted = true
            parent.completedAt = Date()
            
            do {
                try context.save()
            } catch {
                logger.error("Failed to complete parent: \(error.localizedDescription)")
            }
        }
    }
    
    private func hasCircularDependency(startingFrom: Reminder, searchingFor: Reminder, context: ModelContext) -> Bool {
        if startingFrom.uuid == searchingFor.uuid {
            return true
        }

        let startingUUID = startingFrom.uuid
        let descriptor = FetchDescriptor<TaskDependency>(
            predicate: #Predicate<TaskDependency> { $0.blockedTask?.uuid == startingUUID }
        )
        
        guard let dependencies = try? context.fetch(descriptor) else {
            return false
        }
        
        for dependency in dependencies {
            if let blockingTask = dependency.blockingTask {
                if hasCircularDependency(startingFrom: blockingTask, searchingFor: searchingFor, context: context) {
                    return true
                }
            }
        }
        
        return false
    }
}

// MARK: - SwiftData Models

@Model
final class Subtask {
    var id: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var completedAt: Date?
    var createdAt: Date = Date()
    var position: Int = 0
    
    @Relationship(deleteRule: .nullify, inverse: \Reminder.subtasks) var parentReminder: Reminder?
    
    init(title: String, parentReminder: Reminder) {
        self.title = title
        self.parentReminder = parentReminder
        self.createdAt = Date()
    }
}

@Model
final class TaskDependency {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    
    @Relationship(deleteRule: .nullify, inverse: \Reminder.blockingTasks) var blockingTask: Reminder?
    @Relationship(deleteRule: .nullify, inverse: \Reminder.dependencies) var blockedTask: Reminder?
    
    init(blockingTask: Reminder, blockedTask: Reminder) {
        self.blockingTask = blockingTask
        self.blockedTask = blockedTask
        self.createdAt = Date()
    }
}
