import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @State private var showingOnboarding = false
    
    var body: some View {
        MainTabView()
            .task {
                if profiles.isEmpty {
                    showingOnboarding = true
                }
            }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingNameView {
                    showingOnboarding = false
                }
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: UserProfile.self, inMemory: true)
        .environment(AppRouter())
}
