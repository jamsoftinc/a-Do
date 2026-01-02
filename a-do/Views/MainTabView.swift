import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    
    enum Tab {
        case home
        case calendar
        case habits
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)
            
            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(Tab.calendar)
            
            HabitsView()
                .tabItem {
                    Label("Habits", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.habits)
            
            
            NavigationStack {
                SettingsPageView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(Tab.settings)
        }
        .tint(AppTheme.Colors.primary)
    }
}
