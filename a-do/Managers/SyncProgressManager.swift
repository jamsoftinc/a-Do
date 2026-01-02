//
//  SyncProgressManager.swift
//  a-do
//
//  Manages sync progress tracking and user feedback
//

import Foundation
import SwiftUI
import Observation
import os

@MainActor
@Observable
final class SyncProgressManager {
    static let shared = SyncProgressManager()
    
    private let logger = Logger(subsystem: "a-do", category: "SyncProgress")
    
    // Progress tracking
    var isInitialSyncInProgress: Bool = false
    var syncProgress: Double = 0.0
    var currentSyncOperation: String = ""
    var totalOperations: Int = 0
    var completedOperations: Int = 0
    
    // Sync stages
    var isLoadingData: Bool = false
    var isAppleRemindersSync: Bool = false
    var isCloudKitSync: Bool = false
    var isCalendarSync: Bool = false
    
    // Error tracking
    var syncError: String?
    var hasErrors: Bool = false
    
    private init() {}
    
    // MARK: - Progress Management
    
    func startInitialSync() {
        logger.info("Starting initial sync")
        isInitialSyncInProgress = true
        syncProgress = 0.0
        currentSyncOperation = "Initializing..."
        totalOperations = 5 // Data loading, Apple Reminders, CloudKit, Calendar, Cleanup
        completedOperations = 0
        syncError = nil
        hasErrors = false
    }
    
    func updateProgress(operation: String, progress: Double = 0.0) {
        currentSyncOperation = operation
        if progress > 0 {
            syncProgress = progress
        }
        logger.info("Sync progress: \(operation) - \(Int(self.syncProgress * 100))%")
    }
    
    func completeOperation(_ operation: String) {
        completedOperations += 1
        syncProgress = totalOperations > 0 ? Double(self.completedOperations) / Double(self.totalOperations) : 1.0
        currentSyncOperation = operation
        logger.info("Completed operation: \(operation) (\(self.completedOperations)/\(self.totalOperations))")
    }
    
    func finishSync() {
        syncProgress = 1.0
        currentSyncOperation = "Sync completed"
        
        // Delay before hiding to show completion
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                self.isInitialSyncInProgress = false
                self.logger.info("Initial sync finished")
            }
        }
    }
    
    func reportError(_ error: String) {
        syncError = error
        hasErrors = true
        logger.error("Sync error: \(error)")
    }
    
    // MARK: - Stage Management
    
    func startDataLoading() {
        isLoadingData = true
        updateProgress(operation: "Loading app data...")
    }
    
    func finishDataLoading() {
        isLoadingData = false
        completeOperation("App data loaded")
    }
    
    func startAppleRemindersSync() {
        isAppleRemindersSync = true
        updateProgress(operation: "Syncing with Apple Reminders...")
    }
    
    func updateAppleRemindersProgress(imported: Int, exported: Int) {
        let message = "Apple Reminders: \(imported) imported, \(exported) exported"
        updateProgress(operation: message)
    }
    
    func finishAppleRemindersSync() {
        isAppleRemindersSync = false
        completeOperation("Apple Reminders sync completed")
    }
    
    func startCloudKitSync() {
        isCloudKitSync = true
        updateProgress(operation: "Syncing with iCloud...")
    }
    
    func finishCloudKitSync() {
        isCloudKitSync = false
        completeOperation("iCloud sync completed")
    }
    
    func startCalendarSync() {
        isCalendarSync = true
        updateProgress(operation: "Syncing calendar access...")
    }
    
    func finishCalendarSync() {
        isCalendarSync = false
        completeOperation("Calendar sync completed")
    }
    
    func finishCleanup() {
        completeOperation("Cleanup completed")
    }
}

// MARK: - Sync Stage Enum
enum SyncStage {
    case dataLoading
    case appleReminders
    case cloudKit
    case calendar
    case cleanup
    case completed
    
    var displayName: String {
        switch self {
        case .dataLoading: return "Loading Data"
        case .appleReminders: return "Apple Reminders"
        case .cloudKit: return "iCloud Sync"
        case .calendar: return "Calendar Access"
        case .cleanup: return "Finalizing"
        case .completed: return "Completed"
        }
    }
    
    var icon: String {
        switch self {
        case .dataLoading: return "tray.and.arrow.down"
        case .appleReminders: return "checklist"
        case .cloudKit: return "icloud"
        case .calendar: return "calendar"
        case .cleanup: return "sparkles"
        case .completed: return "checkmark.circle.fill"
        }
    }
}
