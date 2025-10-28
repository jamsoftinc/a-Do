//
//  TimeAnalyticsViewWrapper.swift
//  a-do
//
//  Protected wrapper for Time Analytics View
//

import SwiftUI

struct TimeAnalyticsViewWrapper: View {
    @State private var entitlementManager = EntitlementManager.shared
    @State private var showPaywall = false

    var body: some View {
        if entitlementManager.isProUser {
            TimeAnalyticsView()
        } else {
            ProUpgradePromptView(
                feature: .advancedNLP,
                title: "Time Analytics",
                description: "Get detailed insights into how you spend your time with comprehensive analytics, trends, and productivity reports.",
                icon: "chart.bar.fill"
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
        TimeAnalyticsViewWrapper()
    }
}
