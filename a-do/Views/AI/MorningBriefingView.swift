//
//  MorningBriefingView.swift
//  a-do
//
//  Created for iOS 26+ Morning Briefing Feature
//

import SwiftUI
import SwiftData

struct MorningBriefingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var briefingManager = MorningBriefingManager.shared
    @State private var currentPage = 0
    // Gradient colors can be adjusted from briefing content metadata.
    @State private var gradientColors: [Color] = [.blue, .purple, .orange]
    
    var body: some View {
        ZStack {
            // Background - Use app's primary purple theme
            AppTheme.Gradients.primary
                .ignoresSafeArea()
            
            VStack {
                VStack(spacing: 12) {
                    HStack {
                        Button {
                            goHome()
                        } label: {
                            Image(systemName: "house.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.2), in: Circle())
                        }

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.2), in: Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)

                    // Stories Progress Bar
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Capsule()
                                .fill(index <= currentPage ? Color.white : Color.white.opacity(0.3))
                                .frame(height: 4)
                                .animation(.smooth, value: currentPage)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Content
                if let content = briefingManager.currentBriefing {
                    TabView(selection: $currentPage) {
                        BriefingCardView(
                            title: "Good Morning",
                            text: content.greeting,
                            icon: content.weatherIcon
                        )
                        .tag(0)
                        
                        BriefingCardView(
                            title: "Today's Focus",
                            text: content.focus,
                            icon: "target"
                        )
                        .tag(1)
                        
                        BriefingCardView(
                            title: "Daily Motivation",
                            text: content.motivation,
                            icon: "flame.fill"
                        )
                        .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 400)
                } else if briefingManager.isGenerating {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                } else {
                    Button("Generate Briefing") {
                        Task {
                            await briefingManager.generateBriefing(context: modelContext)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
                
                // Action Button
                if currentPage == 2 {
                    Button {
                        briefingManager.markBriefingAsRead()
                        dismiss()
                    } label: {
                        Text("Accept Schedule")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 50)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            if briefingManager.currentBriefing == nil {
                Task {
                    await briefingManager.generateBriefing(context: modelContext)
                }
            }
        }
    }

    private func goHome() {
        NotificationCenter.default.post(name: .appNavigateHome, object: nil)
        dismiss()
    }
}

struct BriefingCardView: View {
    let title: String
    let text: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.white)
                .symbolEffect(.bounce, value: true) // iOS 17+ animation
            
            Text(title)
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            
            Text(text)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    MorningBriefingView()
}
