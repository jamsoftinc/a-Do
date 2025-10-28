//
//  AISettingsViewWrapper.swift
//  a-do
//
//  Protected wrapper for AI Settings View
//

import SwiftUI

struct AISettingsViewWrapper: View {
    @State private var entitlementManager = EntitlementManager.shared
    @State private var showPaywall = false

    var body: some View {
        if entitlementManager.isProUser {
            AISettingsView()
        } else {
            ProUpgradePromptView(
                feature: .advancedNLP,
                title: "AI Settings",
                description: "Customize AI behavior, suggestion frequency, privacy settings, and personalize your AI experience.",
                icon: "brain.head.profile"
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
        AISettingsViewWrapper()
    }
}
