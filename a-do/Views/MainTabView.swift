import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @AppStorage("appAccentColor") private var appAccentColor: String = "#67A2DC"

    @State private var showingTodayFromDeepLink = false
    @State private var showingSmartSearchFromDeepLink = false
    @State private var showingAISuggestions = false
    @State private var showingAIInsights = false
    @State private var showingAISettings = false
    @State private var deepLinkSearchQuery = ""
    @State private var deepLinkSavedSearchID: UUID?
    @State private var deepLinkAlertMessage: String?

    enum Tab {
        case home
        case calendar
        case focus
        case habits
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(Tab.home)

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(Tab.calendar)

            NavigationStack {
                FocusDashboardView()
            }
            .tabItem {
                Label("Focus", systemImage: "scope")
            }
            .tag(Tab.focus)

            HabitsView()
                .tabItem {
                    Label("Habits", systemImage: "chart.bar")
                }
                .tag(Tab.habits)

            NavigationStack {
                SettingsPageView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(Tab.settings)
        }
        .tint(Color(hex: appAccentColor) ?? .accentColor)
        .onAppear {
            if let destination = router.destination {
                handleDeepLink(destination)
            }
        }
        .onChange(of: router.destination) { _, destination in
            guard let destination else { return }
            handleDeepLink(destination)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appNavigateHome)) { _ in
            navigateToHome()
        }
        .fullScreenCover(isPresented: $showingTodayFromDeepLink) {
            NavigationStack {
                TodayView()
            }
        }
        .fullScreenCover(isPresented: $showingSmartSearchFromDeepLink) {
            NavigationStack {
                SmartSearchView(
                    initialQuery: deepLinkSearchQuery,
                    savedSearchID: deepLinkSavedSearchID
                )
            }
        }
        .fullScreenCover(isPresented: $showingAISuggestions) {
            NavigationStack {
                AISuggestionsViewWrapper()
            }
        }
        .fullScreenCover(isPresented: $showingAIInsights) {
            AIInsightsDashboardWrapper()
        }
        .fullScreenCover(isPresented: $showingAISettings) {
            AISettingsViewWrapper()
        }
        .alert("Action Unavailable", isPresented: Binding(
            get: { deepLinkAlertMessage != nil },
            set: { if !$0 { deepLinkAlertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { deepLinkAlertMessage = nil }
        } message: {
            Text(deepLinkAlertMessage ?? "")
        }
    }

    private func navigateToHome() {
        selectedTab = .home
        showingTodayFromDeepLink = false
        showingSmartSearchFromDeepLink = false
        showingAISuggestions = false
        showingAIInsights = false
        showingAISettings = false
        deepLinkSearchQuery = ""
        deepLinkSavedSearchID = nil
        deepLinkAlertMessage = nil
    }

    private func handleDeepLink(_ destination: DeepLinkDestination) {
        switch destination {
        case .smartToday:
            selectedTab = .home
            showingTodayFromDeepLink = true
        case .smartHighPriority:
            selectedTab = .home
            deepLinkSearchQuery = "priority high"
            deepLinkSavedSearchID = nil
            showingSmartSearchFromDeepLink = true
        case .savedSearch(let id):
            selectedTab = .home
            deepLinkSearchQuery = ""
            deepLinkSavedSearchID = id
            showingSmartSearchFromDeepLink = true
        case .tag(let tagName):
            selectedTab = .home
            deepLinkSearchQuery = "#\(tagName)"
            deepLinkSavedSearchID = nil
            showingSmartSearchFromDeepLink = true
        case .priority(let priority):
            selectedTab = .home
            deepLinkSearchQuery = priority.title
            deepLinkSavedSearchID = nil
            showingSmartSearchFromDeepLink = true
        case .sendText(let reminderId):
            selectedTab = .home
            triggerSendText(for: reminderId)
        case .habits:
            selectedTab = .habits
        case .aiSuggestions:
            selectedTab = .home
            showingAISuggestions = true
        case .aiInsights:
            selectedTab = .home
            showingAIInsights = true
        case .aiSettings:
            selectedTab = .settings
            showingAISettings = true
        }

        router.destination = nil
    }

    private func triggerSendText(for reminderId: UUID) {
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { $0.uuid == reminderId }
        )
        guard let reminder = try? context.fetch(descriptor).first else {
            deepLinkAlertMessage = "Could not find the reminder for this message action."
            return
        }

        let recipients = reminder.taggedContacts?
            .compactMap { $0.phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

        guard !recipients.isEmpty else {
            deepLinkAlertMessage = "No phone numbers are tagged on this reminder."
            return
        }

        NotificationManager.shared.composeSMS(to: recipients, body: "Reminder: \(reminder.title)")
    }
}
