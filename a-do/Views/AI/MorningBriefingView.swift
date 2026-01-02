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
    // Using simple colors for MeshGradient for now, would be dynamic in production
    @State private var gradientColors: [Color] = [.blue, .purple, .orange]
    
    var body: some View {
        ZStack {
            // Background
            #if canImport(SwiftUI) && os(iOS)
            if #available(iOS 18.0, *) {
                // iOS 18+ MeshGradient (Simulated syntax for future iOS versions)
                 MeshGradient(
                    width: 3, 
                    height: 3, 
                    points: [
                        .init(0, 0), .init(0.5, 0), .init(1, 0),
                        .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                        .init(0, 1), .init(0.5, 1), .init(1, 1)
                    ], 
                    colors: [
                        .indigo, .purple, .blue,
                        .blue, .cyan, .teal,
                        .indigo, .blue, .purple
                    ]
                )
                .ignoresSafeArea()
                .opacity(0.3)
            } else {
                LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            }
            #else
            Color.black.ignoresSafeArea()
            #endif
            
            VStack {
                // Stories Progress Bar
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Capsule()
                            .fill(index <= currentPage ? Color.white : Color.white.opacity(0.3))
                            .frame(height: 4)
                            .animation(.smooth, value: currentPage)
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal)
                
                Spacer()
                
                // Content
                if let content = briefingManager.currentBriefing {
                    TabView(selection: $currentPage) {
                        BriefingCardView(
                            title: "Good Morning",
                            text: content.greeting,
                            icon: "sun.max.fill"
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
