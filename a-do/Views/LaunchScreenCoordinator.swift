import SwiftUI
import Combine

/// Coordinates the launch screen experience and transition to main app
@MainActor
class LaunchScreenCoordinator: ObservableObject {
    @Published var isLaunchComplete = false
    @Published var launchProgress: Double = 0.0
    
    private var cancellables = Set<AnyCancellable>()
    private let minimumDisplayTime: TimeInterval = 2.0 // Minimum time to show launch screen
    private let startTime = Date()
    
    init() {
        startLaunchSequence()
    }
    
    /// Starts the launch sequence with simulated loading progress
    private func startLaunchSequence() {
        // Simulate app initialization progress
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                if self.launchProgress < 1.0 {
                    // Simulate loading progress
                    self.launchProgress += 0.05
                } else {
                    self.checkLaunchCompletion()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Checks if minimum display time has passed and completes launch
    private func checkLaunchCompletion() {
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        if elapsedTime >= minimumDisplayTime {
            completeLaunch()
        }
    }
    
    /// Completes the launch sequence and transitions to main app
    private func completeLaunch() {
        cancellables.removeAll()
        
        withAnimation(.easeInOut(duration: 0.5)) {
            isLaunchComplete = true
        }
    }
    
    /// Force complete launch (for testing or immediate transitions)
    func forceCompleteLaunch() {
        completeLaunch()
    }
}

/// Launch screen wrapper that handles the transition to main content
struct LaunchScreenWrapper<Content: View>: View {
    @StateObject private var coordinator = LaunchScreenCoordinator()
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        ZStack {
            if coordinator.isLaunchComplete {
                content()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                LaunchScreenView()
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: coordinator.isLaunchComplete)
    }
}

// MARK: - Preview

#Preview {
    LaunchScreenWrapper {
        Text("Main App Content")
            .font(.title)
            .foregroundColor(.white)
    }
}
