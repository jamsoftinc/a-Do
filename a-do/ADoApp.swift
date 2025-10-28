//
//  ADoApp.swift
//  a-do
//
//  Created by Ahmad Hamilton on 8/10/25.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct ADoApp: App {
    init() {
        // Initialize app group defaults early to prevent CFPrefsPlistSource errors
        _ = AppGroupDefaults.shared
        
        // Configure global navigation bar appearance
        configureGlobalAppearance()
        
        // Initialize location manager and request permission
        let locationManager = LocationManager.shared
        locationManager.requestAuthorization(always: false)
        
        // Initialize subscription manager
        _ = SubscriptionManager.shared
        _ = EntitlementManager.shared
        
        // Initialize memory monitor
        _ = MemoryMonitor.shared
    }
    
    private func configureGlobalAppearance() {
        // Navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.Colors.primary)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor.white
        
        // Toolbar appearance
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithOpaqueBackground()
        toolbarAppearance.backgroundColor = UIColor(AppTheme.Colors.surface)
        UIToolbar.appearance().standardAppearance = toolbarAppearance
        UIToolbar.appearance().compactAppearance = toolbarAppearance
        UIToolbar.appearance().tintColor = UIColor.white
        
        // Tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppTheme.Colors.surface)
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = UIColor.white
        UITabBar.appearance().unselectedItemTintColor = UIColor(AppTheme.Colors.textTertiary)
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var router = AppRouter()
    @State private var container: ModelContainer?
    @State private var syncManager = SyncProgressManager.shared
    @State private var isInitialSyncComplete = false
    
    var body: some View {
        LaunchScreenWrapper {
            if let container = container {
                if syncManager.isInitialSyncInProgress && !isInitialSyncComplete {
                    // Show sync progress during initial sync
                    SyncProgressView()
                        .modelContainer(container)
                        .task {
                            await performInitialSync(container: container)
                        }
                } else {
                    // Show main app content
                    ContentView()
                        .modelContainer(container)
                        .environment(router)
                        .onOpenURL { url in router.handle(url: url) }
                        .task { router.checkGroupDeeplinkFlag() }
                }
            } else {
                // Show loading state while container initializes
                ProgressView("Initializing...")
                    .task {
                        // Initialize container on background thread
                        container = AppContainer.shared.getContainer()
                    }
            }
        }
        .onChange(of: syncManager.isInitialSyncInProgress) { _, inProgress in
            if !inProgress {
                isInitialSyncComplete = true
            }
        }
    }
    
    private func performInitialSync(container: ModelContainer) async {
        let context = ModelContext(container)
        
        // Start the sync process
        await MainActor.run {
            syncManager.startInitialSync()
        }
        
        // Stage 1: Data Loading
        await MainActor.run {
            syncManager.startDataLoading()
        }
        
        // Simulate data loading time
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            syncManager.finishDataLoading()
        }
        
        // Stage 2: Apple Reminders Sync
        await MainActor.run {
            syncManager.startAppleRemindersSync()
        }
        
        // Check if this is the first sync
        let isFirstSync = SettingsManager.shared.isFirstSync(context: context)
        
        // Perform Apple Reminders sync
        await AppleRemindersSyncManager.shared.performFullSync(context: context, isInitialSync: isFirstSync)
        
        await MainActor.run {
            syncManager.finishAppleRemindersSync()
        }
        
        // Stage 3: CloudKit Sync
        await MainActor.run {
            syncManager.startCloudKitSync()
        }
        
        // CloudKit operations
        CloudKitManager.shared.loadSyncSetting(context: context)
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            syncManager.finishCloudKitSync()
        }
        
        // Stage 4: Calendar Sync
        await MainActor.run {
            syncManager.startCalendarSync()
        }
        
        // Calendar operations
        await CalendarManager.shared.requestAccess()
        
        await MainActor.run {
            syncManager.finishCalendarSync()
        }
        
        // Stage 5: Cleanup
        await MainActor.run {
            syncManager.finishCleanup()
        }
        
        // Mark first sync as completed if this was the initial sync
        if isFirstSync {
            SettingsManager.shared.markFirstSyncCompleted(context: context)
        }
        
        // Complete the sync
        await MainActor.run {
            syncManager.finishSync()
        }
    }
}

