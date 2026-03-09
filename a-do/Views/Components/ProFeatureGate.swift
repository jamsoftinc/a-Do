//
//  ProFeatureGate.swift
//  a-do
//
//  Pro feature gating with paywall integration
//

import SwiftUI

struct ProFeatureGate<Content: View>: View {
    let feature: ProFeature
    let content: Content
    let fallback: (() -> Void)?

    @State private var showingPaywall = false
    @State private var entitlementManager = EntitlementManager.shared

    init(feature: ProFeature, @ViewBuilder content: () -> Content, fallback: (() -> Void)? = nil) {
        self.feature = feature
        self.content = content()
        self.fallback = fallback
    }

    var body: some View {
        if entitlementManager.hasAccess(to: feature) {
            content
        } else {
            Button(action: {
                showingPaywall = true
            }) {
                content
                    .opacity(0.5)
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)

                            Text("Pro Feature")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(AppTheme.Colors.surface,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }
}

// MARK: - Pro Feature Button

struct ProFeatureButton: View {
    let feature: ProFeature
    let title: String
    let icon: String
    let action: () -> Void

    @State private var showingPaywall = false
    @State private var entitlementManager = EntitlementManager.shared

    init(feature: ProFeature, title: String, icon: String, action: @escaping () -> Void) {
        self.feature = feature
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: {
            action()
        }) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                if !entitlementManager.hasAccess(to: feature) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
}

// MARK: - Pro Feature Card

struct ProFeatureCard: View {
    let feature: ProFeature
    let title: String
    let description: String
    let icon: String
    let action: () -> Void

    @State private var showingPaywall = false
    @State private var entitlementManager = EntitlementManager.shared

    init(feature: ProFeature, title: String, description: String, icon: String, action: @escaping () -> Void) {
        self.feature = feature
        self.title = title
        self.description = description
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: {
            if entitlementManager.hasAccess(to: feature) {
                action()
            } else {
                showingPaywall = true
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(entitlementManager.hasAccess(to: feature) ? Color.accentColor : .secondary)

                    Spacer()

                    if !entitlementManager.hasAccess(to: feature) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color(.label))

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(16)
            .background(AppTheme.Colors.surface,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ProFeatureButton(
            feature: .advancedNLP,
            title: "AI Features",
            icon: "sparkles"
        ) {
            print("AI Features tapped")
        }

        ProFeatureCard(
            feature: .liveActivities,
            title: "Live Activities",
            description: "Real-time updates on your lock screen",
            icon: "livephoto"
        ) {
            print("Live Activities tapped")
        }
    }
    .padding()
}
