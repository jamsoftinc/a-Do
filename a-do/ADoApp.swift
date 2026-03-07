//
//  ADoApp.swift
//  a-do
//
//  Created by Ahmad Hamilton on 8/10/25.
//

import SwiftUI
import SwiftData
import UIKit
import FirebaseCore

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseBootstrapper.configureIfNeeded()
        return true
    }
}

enum FirebaseBootstrapper {
    private static var didConfigure = false

    static func configureIfNeeded() {
        guard !didConfigure else { return }

        if let options = FirebaseOptions.defaultOptions() {
            FirebaseApp.configure(options: options)
            didConfigure = true
            return
        }

        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: plistPath) else {
            assertionFailure("GoogleService-Info.plist is missing from the app bundle or unreadable.")
            return
        }

        FirebaseApp.configure(options: options)
        didConfigure = true
    }
}

@main
struct ADoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Initialize app group defaults early to prevent CFPrefsPlistSource errors
        _ = AppGroupDefaults.shared

        FirebaseBootstrapper.configureIfNeeded()
        
        // Configure global navigation bar appearance
        configureGlobalAppearance()
        
        // Initialize subscription manager
        _ = SubscriptionManager.shared
        _ = EntitlementManager.shared
        _ = GeminiManager.shared
        GeminiManager.shared.bootstrapIfNeeded()
        
        // Initialize memory monitor
        _ = MemoryMonitor.shared
    }
    
    private func configureGlobalAppearance() {
        // Navigation bar — system default (translucent, adapts to light/dark)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // Toolbar — system default
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithDefaultBackground()
        UIToolbar.appearance().standardAppearance = toolbarAppearance
        UIToolbar.appearance().compactAppearance = toolbarAppearance

        // Tab bar — system default
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
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
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("appAccentColor") private var appAccentColor: String = "#336BDB"
    
    @State private var showMorningBriefing = false
    @State private var isThoughtStreamActive = false
    
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
                        .tint(Color(hex: appAccentColor) ?? AppTheme.Colors.primary)
                        .preferredColorScheme(preferredColorScheme)
                        .onOpenURL { url in router.handle(url: url) }
                        .task { 
                            router.checkGroupDeeplinkFlag() 
                            checkMorningBriefingStatus()
                            refreshWidgetSnapshotsIfPossible()
                        }
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReminderCreated"))) { _ in
                            refreshWidgetSnapshotsIfPossible()
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                            refreshWidgetSnapshotsIfPossible()
                        }
                        .fullScreenCover(isPresented: $showMorningBriefing) {
                            MorningBriefingView()
                                .modelContainer(container)
                        }
                }
            } else {
                // Show loading state while container initializes
                ProgressView("Initializing...")
                    .task {
                        // Initialize container on background thread
                        container = AppContainer.shared.getContainer()
                        if let container {
                            StartupSmokeChecks.run(container: container)
                        }
                    }
                }
        
            if isThoughtStreamActive {
                if EntitlementManager.shared.isProUser {
                    ThoughtStreamView(isActive: $isThoughtStreamActive)
                } else {
                    // Fallback locked state if somehow triggered
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: 20) {
                            Image(systemName: "lock.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                            Text("Thought Stream is a Pro Feature")
                                .foregroundStyle(.white)
                            Button("Dismiss") {
                                isThoughtStreamActive = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
        .onChange(of: syncManager.isInitialSyncInProgress) { _, inProgress in
            if !inProgress {
                isInitialSyncComplete = true
                refreshWidgetSnapshotsIfPossible()
            }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appTheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
    
    private func checkMorningBriefingStatus() {
        guard EntitlementManager.shared.isProUser else { return }
        
        let manager = MorningBriefingManager.shared
        let calendar = Calendar.current
        
        if let lastDate = manager.lastGeneratedDate,
           calendar.isDateInToday(lastDate) {
            return
        }
        
        showMorningBriefing = true
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

        await MainActor.run {
            WidgetSnapshotManager.shared.refreshSnapshots(context: context)
        }
    }

    private func refreshWidgetSnapshotsIfPossible() {
        guard let container else { return }
        let context = ModelContext(container)
        WidgetSnapshotManager.shared.refreshSnapshots(context: context)
    }
}
