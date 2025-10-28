//
//  AIInsightsDashboardWrapper.swift
//  a-do
//
//  Protected wrapper for AI Insights Dashboard
//

import SwiftUI

struct AIInsightsDashboardWrapper: View {
    @State private var entitlementManager = EntitlementManager.shared
    @State private var showPaywall = false

    var body: some View {
        if entitlementManager.isProUser {
            AIInsightsDashboard()
        } else {
            ProUpgradePromptView(
                feature: .advancedNLP,
                title: "AI Insights",
                description: "Get intelligent insights about your productivity, habits, and time usage powered by AI.",
                icon: "chart.line.uptrend.xyaxis"
            ) {
                showPaywall = true
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

struct ProUpgradePromptView: View {
    let feature: ProFeature
    let title: String
    let description: String
    let icon: String
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.purple)
                        Text("Pro Feature")
                            .font(.headline)
                            .foregroundColor(.purple)
                    }

                    Text(title)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()

            Button(action: onUpgrade) {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Upgrade to Pro")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .navigationTitle(title)
    }
}

#Preview {
    NavigationStack {
        AIInsightsDashboardWrapper()
    }
}
