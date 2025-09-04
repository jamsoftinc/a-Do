//
//  CloudKitManager.swift
//  a-do
//
//  Created by Ahmad Hamilton on 8/10/25.
//

import Foundation
import CloudKit
import SwiftData
import Combine
import os

@MainActor
final class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    @Published var isSignedIn: Bool = false
    @Published var syncStatus: CloudKitSyncStatus = .unknown
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var isSyncEnabled: Bool = true
    
    private let container = CKContainer(identifier: "iCloud.JAMSoft.a-do")
    private let logger = Logger(subsystem: "a-do", category: "CloudKit")
    
    private init() {
        checkAccountStatus()
    }
    
    func loadSyncSetting(context: ModelContext) {
        let settings = SettingsManager.shared.getSettings(context: context)
        setSyncEnabled(settings.iCloudSyncEnabled)
    }
    
    // MARK: - Account Status
    
    func checkAccountStatus() {
        Task {
            do {
                let status = try await container.accountStatus()
                await MainActor.run {
                    self.isSignedIn = (status == .available)
                    self.logger.info("CloudKit account status: \(status.rawValue)")
                    
                    // Update sync status based on account status
                    if status == .available {
                        self.updateSyncStatus(.success)
                    } else if status == .noAccount {
                        self.updateSyncStatus(.failed("No iCloud account signed in"))
                    } else if status == .restricted {
                        self.updateSyncStatus(.failed("iCloud account is restricted"))
                    } else if status == .couldNotDetermine {
                        self.updateSyncStatus(.failed("Could not determine iCloud account status"))
                    } else {
                        self.updateSyncStatus(.unknown)
                    }
                }
            } catch {
                await MainActor.run {
                    self.syncError = "Failed to check CloudKit account: \(error.localizedDescription)"
                    self.logger.error("CloudKit account check failed: \(error.localizedDescription)")
                    self.updateSyncStatus(.failed(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Sync Status
    
    func updateSyncStatus(_ status: CloudKitSyncStatus) {
        self.syncStatus = status
        self.lastSyncDate = Date()
        
        switch status {
        case .syncing:
            self.syncError = nil
        case .success:
            self.syncError = nil
        case .failed(let error):
            self.syncError = error
        case .unknown:
            break
        }
        
        logger.info("CloudKit sync status updated: \(String(describing: status))")
    }
    
    func setSyncEnabled(_ enabled: Bool) {
        self.isSyncEnabled = enabled
        if !enabled {
            self.syncStatus = .unknown
            self.syncError = "iCloud sync is disabled"
        } else {
            // Re-check account status when enabling sync
            checkAccountStatus()
        }
        logger.info("iCloud sync enabled: \(enabled)")
    }
    
    func refreshAccountStatus() {
        checkAccountStatus()
    }
    
    // MARK: - User Feedback
    
    var syncStatusMessage: String {
        if !isSyncEnabled {
            return "iCloud sync disabled"
        }
        
        switch syncStatus {
        case .unknown:
            return "Checking sync status..."
        case .syncing:
            return "Syncing with iCloud..."
        case .success:
            if let lastSync = lastSyncDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
            }
            return "Synced with iCloud"
        case .failed(let error):
            return "Sync failed: \(error)"
        }
    }
    
    var syncStatusColor: String {
        if !isSyncEnabled {
            return "#8E8E93" // Gray
        }
        
        switch syncStatus {
        case .unknown:
            return "#FFA500" // Orange
        case .syncing:
            return "#007AFF" // Blue
        case .success:
            return "#34C759" // Green
        case .failed:
            return "#FF3B30" // Red
        }
    }
    
    var syncStatusIcon: String {
        if !isSyncEnabled {
            return "icloud.slash.fill"
        }
        
        switch syncStatus {
        case .unknown:
            return "icloud.slash"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .success:
            return "icloud.fill"
        case .failed:
            return "icloud.slash.fill"
        }
    }
}

// MARK: - CloudKit Sync Status

enum CloudKitSyncStatus: Equatable {
    case unknown
    case syncing
    case success
    case failed(String)
    
    static func == (lhs: CloudKitSyncStatus, rhs: CloudKitSyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown), (.syncing, .syncing), (.success, .success):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}
