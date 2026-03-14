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
    
    private let container: CKContainer?
    private let logger = Logger(subsystem: "a-do", category: "CloudKit")
    
    private init() {
        if RuntimeEnvironment.isRunningTests {
            container = nil
            isSignedIn = false
            syncStatus = .unknown
            return
        }

        container = CKContainer.default()
        checkAccountStatus()
    }
    
    func loadSyncSetting(context: ModelContext) {
        let settings = SettingsManager.shared.getSettings(context: context)
        setSyncEnabled(settings.iCloudSyncEnabled)
    }
    
    // MARK: - Account Status
    
    func checkAccountStatus() {
        guard let container else {
            logger.info("Skipping CloudKit account check in test environment")
            return
        }

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
                let message = Self.userFacingMessage(for: error)
                await MainActor.run {
                    self.syncError = "Failed to check CloudKit account: \(message)"
                    self.logger.error("CloudKit account check failed: \(message)")
                    self.updateSyncStatus(.failed(message))
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

    nonisolated private static func userFacingMessage(for error: Error) -> String {
        if let ckError = error as? CKError, ckError.code == .badContainer {
            return "This app build is not authorized for the configured CloudKit container. Verify the app ID, iCloud capability, and assigned container in Signing & Capabilities."
        }

        let description = error.localizedDescription
        if description.localizedCaseInsensitiveContains("invalid bundle id for container") {
            return "This app build is not authorized for the configured CloudKit container. Verify the app ID, iCloud capability, and assigned container in Signing & Capabilities."
        }

        return description
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
