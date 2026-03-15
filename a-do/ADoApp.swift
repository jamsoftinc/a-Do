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
        BackgroundMaintenanceManager.shared.registerTasks()
        BackgroundMaintenanceManager.shared.scheduleAll(reason: "launch")
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
    private let defaultAccentColor = "#67A2DC"
    private let legacyAccentColor = "#336BDB"

    init() {
        // Initialize app group defaults early to prevent CFPrefsPlistSource errors
        _ = AppGroupDefaults.shared

        FirebaseBootstrapper.configureIfNeeded()
        migrateAccentColorIfNeeded()
        
        // Configure global navigation bar appearance
        configureGlobalAppearance()

        guard !RuntimeEnvironment.isRunningTests else { return }

        // Initialize subscription manager
        _ = SubscriptionManager.shared
        _ = EntitlementManager.shared
        
        // Initialize memory monitor
        _ = MemoryMonitor.shared
    }
    
    private func configureGlobalAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppTheme.UIColors.background
        appearance.titleTextAttributes = [.foregroundColor: AppTheme.UIColors.textPrimary]
        appearance.largeTitleTextAttributes = [.foregroundColor: AppTheme.UIColors.textPrimary]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithOpaqueBackground()
        toolbarAppearance.backgroundColor = AppTheme.UIColors.surface
        UIToolbar.appearance().standardAppearance = toolbarAppearance
        UIToolbar.appearance().compactAppearance = toolbarAppearance

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = AppTheme.UIColors.surface
        configureTabBarLayout(tabBarAppearance.stackedLayoutAppearance)
        configureTabBarLayout(tabBarAppearance.inlineLayoutAppearance)
        configureTabBarLayout(tabBarAppearance.compactInlineLayoutAppearance)
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    private func configureTabBarLayout(_ layoutAppearance: UITabBarItemAppearance) {
        layoutAppearance.normal.iconColor = AppTheme.UIColors.textSecondary
        layoutAppearance.normal.titleTextAttributes = [.foregroundColor: AppTheme.UIColors.textSecondary]
    }

    private func migrateAccentColorIfNeeded() {
        let defaults = UserDefaults.standard
        guard let accentColor = defaults.string(forKey: "appAccentColor") else {
            defaults.set(defaultAccentColor, forKey: "appAccentColor")
            return
        }

        if accentColor.caseInsensitiveCompare(legacyAccentColor) == .orderedSame {
            defaults.set(defaultAccentColor, forKey: "appAccentColor")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = AppRouter()
    @State private var container: ModelContainer?
    @State private var syncManager = SyncProgressManager.shared
    @State private var isInitialSyncComplete = false
    @State private var maintenanceTask: Task<Void, Never>?
    @State private var recoveryMessage: String?
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("appAccentColor") private var appAccentColor: String = "#67A2DC"
    
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
                        .onContinueUserActivity("com.apple.corespotlightitem") { activity in
                            router.handleSpotlightActivity(activity)
                        }
                        .task { 
                            router.checkGroupDeeplinkFlag() 
                            checkMorningBriefingStatus()
                            refreshWidgetSnapshotsIfPossible()
                            scheduleLifecycleMaintenance(reason: "launch")
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
                            recoveryMessage = AppContainer.shared.recoveryMessage
                            Task {
                                await StartupSmokeChecks.run(container: container)
                            }
                            SettingsManager.shared.migrateAccentColorIfNeeded(context: ModelContext(container))
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
        .safeAreaInset(edge: .top) {
            if let recoveryMessage {
                HStack(spacing: 12) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .foregroundStyle(.orange)
                    Text(recoveryMessage)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button("Dismiss") {
                        self.recoveryMessage = nil
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
        .onChange(of: syncManager.isInitialSyncInProgress) { _, inProgress in
            if !inProgress {
                isInitialSyncComplete = true
                refreshWidgetSnapshotsIfPossible()
                scheduleLifecycleMaintenance(reason: "initialSyncComplete")
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                refreshWidgetSnapshotsIfPossible()
                scheduleLifecycleMaintenance(reason: "sceneActive")
                if recoveryMessage == nil {
                    recoveryMessage = AppContainer.shared.recoveryMessage
                }
            case .background:
                BackgroundMaintenanceManager.shared.scheduleAll(reason: "sceneBackground")
            default:
                break
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

        CloudKitManager.shared.loadSyncSetting(context: context)

        await MainActor.run {
            syncManager.finishCloudKitSync()
        }
        
        // Stage 4: Calendar Sync
        await MainActor.run {
            syncManager.startCalendarSync()
        }

        CalendarManager.shared.refreshAuthorizationStatus()
        if CalendarManager.shared.accessGranted {
            await CalendarManager.shared.loadEvents()
        }

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
            WidgetSnapshotManager.shared.refreshSnapshots(
                context: context,
                kinds: [.reminders, .habits, .focus, .timeTracking]
            )
        }
    }

    private func refreshWidgetSnapshotsIfPossible() {
        guard let container else { return }
        let context = ModelContext(container)
        WidgetSnapshotManager.shared.refreshSnapshots(
            context: context,
            kinds: [.reminders, .habits, .focus, .timeTracking]
        )
    }

    private func scheduleLifecycleMaintenance(reason: String) {
        guard let container else { return }
        maintenanceTask?.cancel()
        maintenanceTask = Task(priority: .utility) {
            await runLifecycleMaintenance(container: container, reason: reason)
        }
    }

    private func runLifecycleMaintenance(container: ModelContainer, reason: String) async {
        let context = ModelContext(container)
        let userId = SecurityUtils.getCurrentUserID()

        await AppleRemindersSyncManager.shared.performLifecycleSyncIfNeeded(context: context, reason: reason)
        await AdvancedSearchManager.shared.refreshIndexIfNeeded(context: context, reason: reason)
        await RecurringRemindersManager.shared.processRecurringRemindersIfNeeded(context: context, reason: reason)
        await SmartNotificationManager.shared.performMaintenanceIfNeeded(context: context, reason: reason)
        await BackupManager.shared.checkScheduledBackupsIfNeeded(context: context, reason: reason)
        await BehavioralLearningManager.shared.flushIfNeeded(context: context, reason: reason)
        await AIBehavioralIntegrationCoordinator.shared.runLearningCycleIfNeeded(context: context, reason: reason)
        await AIManager.shared.refreshIfNeeded(userId: userId, context: context, reason: reason)
        await GamificationManager.shared.refreshIfNeeded(context: context, reason: reason)
    }
}
