import SwiftUI
import SwiftData

struct OnboardingNameView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName: String = ""
    @State private var isAnimating = false
    @FocusState private var isFocused: Bool
    
    // Callback to notify when onboarding is complete
    var onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient matching the app's aesthetic
            AppTheme.Gradients.background
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Welcome Text
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
                
                // Input Field
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
                            if !firstName.isEmpty {
                                saveProfileAndContinue()
                            }
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
                
                // Continue Button
                Button {
                    saveProfileAndContinue()
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
                .disabled(firstName.isEmpty)
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8, blendDuration: 0).delay(0.3)) {
                isAnimating = true
            }
            // Delay focus to ensure view is rendered
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
    }
    
    private func saveProfileAndContinue() {
        let profile = UserProfile(userId: UUID().uuidString, displayName: firstName)
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
