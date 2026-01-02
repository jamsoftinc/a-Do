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
                    .opacity(0.6)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                            
                            Text("Pro Feature")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
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
            // Always call action - wrapper views handle Pro checking
            action()
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(entitlementManager.hasAccess(to: feature) ? .primary : .purple)

                Text(title)
                    .foregroundColor(.primary)

                Spacer()

                // Always show Pro badge for Pro features
                Image(systemName: "crown.fill")
                    .foregroundColor(entitlementManager.hasAccess(to: feature) ? .orange : .purple)
                    .font(.caption)
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
                        .foregroundColor(entitlementManager.hasAccess(to: feature) ? .blue : .purple)
                    
                    Spacer()
                    
                    if !entitlementManager.hasAccess(to: feature) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.purple)
                            .font(.caption)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(entitlementManager.hasAccess(to: feature) ? .clear : .purple.opacity(0.3), lineWidth: 1)
                    )
            )
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
