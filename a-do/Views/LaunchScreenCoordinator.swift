import SwiftUI
import Combine

/// Coordinates the launch screen experience and transition to main app
@MainActor
class LaunchScreenCoordinator: ObservableObject {
    @Published var isLaunchComplete = false
    @Published var launchProgress: Double = 0.0
    
    private var launchTask: Task<Void, Never>?
    
    init() {
        startLaunchSequence()
    }
    
    /// Starts the launch sequence and advances progress after each startup phase.
    private func startLaunchSequence() {
        launchTask?.cancel()
        launchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            await self.runLaunchPhase(progress: 0.2) {
                _ = AppGroupDefaults.shared
            }
            
            await self.runLaunchPhase(progress: 0.45) {
                _ = AppContainer.shared.getContainer()
            }
            
            await self.runLaunchPhase(progress: 0.7) {
                guard !RuntimeEnvironment.isRunningTests else { return }
                _ = SubscriptionManager.shared
                _ = EntitlementManager.shared
                _ = NotificationManager.shared
            }
            
            await self.runLaunchPhase(progress: 0.9) {
                guard !RuntimeEnvironment.isRunningTests else { return }
                _ = MemoryMonitor.shared
            }
            
            self.launchProgress = 1.0
            self.completeLaunch()
        }
    }
    
    /// Completes the launch sequence and transitions to main app
    private func completeLaunch() {
        launchTask?.cancel()
        launchTask = nil
        
        withAnimation(.easeInOut(duration: 0.5)) {
            isLaunchComplete = true
        }
    }
    
    /// Force complete launch (for testing or immediate transitions)
    func forceCompleteLaunch() {
        launchProgress = 1.0
        completeLaunch()
    }
    
    private func runLaunchPhase(progress: Double, action: () -> Void) async {
        action()
        launchProgress = max(launchProgress, min(progress, 1.0))
        await Task.yield()
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
