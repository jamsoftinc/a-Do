import SwiftUI
import SwiftData
import AVFoundation

struct OnboardingNameView: View {
    @Environment(\.modelContext) private var context
    
    @State private var firstName: String = ""
    @State private var isAnimating = false
    @FocusState private var isFocused: Bool
    @State private var step: Step = .name
    @State private var notificationsGranted = false
    @State private var locationRequested = false
    @State private var microphoneGranted = false
    
    // Callback to notify when onboarding is complete
    var onComplete: () -> Void

    private enum Step {
        case name
        case permissions
    }
    
    var body: some View {
        ZStack {
            // Background gradient matching the app's aesthetic
            AppTheme.Gradients.background
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                if step == .name {
                    nameStep
                } else {
                    permissionStep
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8, blendDuration: 0)) {
                isAnimating = true
            }
            
            // Delay focus slightly to ensure view is fully visible and interactive
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isFocused = true
            }
        }
    }

    private var nameStep: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 16) {
                Text("Welcome")
                    .font(AppTheme.Typography.largeTitle)
                    .primaryText()
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)

                Text("What should we call you?")
                    .font(AppTheme.Typography.title2)
                    .secondaryText()
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)

                TextField("First Name", text: $firstName)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .focused($isFocused)
                    .textInputAutocapitalization(.words)
                    .padding()
                    .submitLabel(.continue)
                    .onSubmit {
                        proceedToPermissions()
                    }
            }
            .frame(height: 60)
            .padding(.horizontal, 40)
            .opacity(isAnimating ? 1 : 0)
            .scaleEffect(isAnimating ? 1 : 0.9)
            .onTapGesture {
                isFocused = true
            }

            Spacer()

            Button {
                proceedToPermissions()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        !firstName.isEmpty ? AppTheme.Gradients.primary : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: (!firstName.isEmpty ? AppTheme.Colors.primary : .gray).opacity(0.4), radius: 10, x: 0, y: 5)
            }
            .disabled(firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
            .opacity(isAnimating ? 1 : 0)
            .offset(y: isAnimating ? 0 : 20)
        }
    }

    private var permissionStep: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                Text("Set Up Permissions")
                    .font(AppTheme.Typography.title1)
                    .primaryText()
                Text("Enable these when you need them. You can change anytime in Settings.")
                    .font(AppTheme.Typography.subheadline)
                    .secondaryText()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            VStack(spacing: 12) {
                permissionRow(
                    title: "Notifications",
                    subtitle: notificationsGranted ? "Enabled" : "Get due reminders on time",
                    icon: "bell.badge.fill",
                    isEnabled: notificationsGranted,
                    action: requestNotifications
                )

                permissionRow(
                    title: "Location",
                    subtitle: locationRequested ? "Requested" : "Enable place-based reminders",
                    icon: "location.fill",
                    isEnabled: locationRequested,
                    action: requestLocation
                )

                permissionRow(
                    title: "Microphone",
                    subtitle: microphoneGranted ? "Enabled" : "Create voice reminders quickly",
                    icon: "mic.fill",
                    isEnabled: microphoneGranted,
                    action: requestMicrophone
                )
            }
            .padding(.horizontal, 20)

            Spacer()

            Button {
                saveProfileAndContinue()
            } label: {
                Text("Finish Setup")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.Gradients.primary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
    }

    private func permissionRow(
        title: String,
        subtitle: String,
        icon: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppTheme.Colors.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .primaryText()
                Text(subtitle)
                    .font(.caption)
                    .secondaryText()
            }

            Spacer()

            Button(isEnabled ? "Done" : "Enable") {
                action()
            }
            .buttonStyle(.borderedProminent)
            .tint(isEnabled ? AppTheme.Colors.success : AppTheme.Colors.primary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func proceedToPermissions() {
        guard !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            step = .permissions
            isFocused = false
        }
    }

    private func requestNotifications() {
        NotificationManager.shared.requestAuthorization()
        NotificationManager.shared.refreshStatus()
        notificationsGranted = true
    }

    private func requestLocation() {
        LocationManager.shared.requestAuthorization(always: false)
        locationRequested = true
    }

    private func requestMicrophone() {
        Task {
            let granted = await AudioManager.shared.requestMicrophonePermission()
            await MainActor.run {
                microphoneGranted = granted
            }
        }
    }
    
    private func saveProfileAndContinue() {
        let profile = UserProfile(userId: UUID().uuidString, displayName: firstName.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(profile)
        
        // Add basic achievements
        // We could initiate some default state here if needed
        
        try? context.save()
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        onComplete()
    }
}

#Preview {
    OnboardingNameView(onComplete: {})
        .modelContainer(for: UserProfile.self, inMemory: true)
}
