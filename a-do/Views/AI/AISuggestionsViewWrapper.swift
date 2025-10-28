//
//  AISuggestionsViewWrapper.swift
//  a-do
//
//  Protected wrapper for AI Suggestions View
//

import SwiftUI

struct AISuggestionsViewWrapper: View {
    @State private var entitlementManager = EntitlementManager.shared
    @State private var showPaywall = false

    var body: some View {
        if entitlementManager.isProUser {
            AISuggestionsView()
        } else {
            ProUpgradePromptView(
                feature: .advancedNLP,
                title: "AI Suggestions",
                description: "Get personalized AI-powered suggestions to improve your productivity and optimize your workflow.",
                icon: "sparkles"
            ) {
                showPaywall = true
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        AISuggestionsViewWrapper()
    }
}
