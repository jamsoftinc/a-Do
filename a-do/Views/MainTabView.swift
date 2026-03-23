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
    @State private var deepLinkSearchScope: SearchScope = .all
    @State private var deepLinkSavedSearchID: UUID?
    @State private var deepLinkAlertMessage: String?

    enum Tab {
        case home
        case capture
        case focus
        case calendar
        case insights
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "sparkles")
                }
                .tag(Tab.home)

            CaptureView()
                .tabItem {
                    Label("Capture", systemImage: "mic.fill")
                }
                .tag(Tab.capture)

            NavigationStack {
                FocusDashboardView()
            }
            .tabItem {
                Label("Focus", systemImage: "timer")
            }
            .tag(Tab.focus)

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(Tab.calendar)

            InsightsHabitsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.insights)
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
                    savedSearchID: deepLinkSavedSearchID,
                    initialScope: deepLinkSearchScope
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
        deepLinkSearchScope = .all
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
            deepLinkSearchScope = .all
            deepLinkSavedSearchID = id
            showingSmartSearchFromDeepLink = true
        case .search(let query, let scope):
            selectedTab = .home
            deepLinkSearchQuery = query
            deepLinkSearchScope = scope
            deepLinkSavedSearchID = nil
            showingSmartSearchFromDeepLink = true
        case .tag(let tagName):
            selectedTab = .home
            deepLinkSearchQuery = "#\(tagName)"
            deepLinkSearchScope = .all
            deepLinkSavedSearchID = nil
            showingSmartSearchFromDeepLink = true
        case .priority(let priority):
            selectedTab = .home
            deepLinkSearchQuery = priority.title
            deepLinkSearchScope = .all
            deepLinkSavedSearchID = nil
            showingSmartSearchFromDeepLink = true
        case .sendText(let reminderId):
            selectedTab = .home
            triggerSendText(for: reminderId)
        case .habits:
            selectedTab = .insights
        case .aiSuggestions:
            selectedTab = .home
            showingAISuggestions = true
        case .aiInsights:
            selectedTab = .home
            showingAIInsights = true
        case .aiSettings:
            selectedTab = .home
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
