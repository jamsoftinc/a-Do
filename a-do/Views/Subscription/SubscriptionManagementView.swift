//
//  SubscriptionManagementView.swift
//  a-do
//
//  Subscription management and account view
//

import SwiftUI
import StoreKit

struct SubscriptionManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var entitlementManager = EntitlementManager.shared
    @State private var showingPaywall = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        List {
            // Current Subscription Status
            statusSection
            
            // Subscription Options
            subscriptionOptionsSection
            
            // Account Actions
            accountActionsSection
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await subscriptionManager.updateSubscriptionStatus()
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Plan")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(statusText)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let expiration = expirationText {
                        Text(expiration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: isPro ? "crown.fill" : "crown")
                    .font(.title)
                    .foregroundColor(isPro ? .yellow : .gray)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Status")
        } footer: {
            if entitlementManager.isInFreeTrial, let daysRemaining = entitlementManager.daysRemainingInTrial {
                Text("Your free trial has \(daysRemaining) day\(daysRemaining == 1 ? "" : "s") remaining")
            }
        }
    }
    
    // MARK: - Subscription Options Section
    
    private var subscriptionOptionsSection: some View {
        Section {
            if !isPro {
                Button {
                    showingPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text("Upgrade to Pro")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if isPro {
                Button {
                    Task {
                        await openManageSubscriptions()
                    }
                } label: {
                    HStack {
                        Image(systemName: "gearshape")
                            .foregroundColor(.blue)
                        Text("Manage Subscription")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Plan")
        }
    }
    
    // MARK: - Account Actions Section
    
    private var accountActionsSection: some View {
        Section {
            Button {
                Task {
                    await restorePurchases()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundColor(.blue)
                    Text("Restore Purchases")
                        .foregroundColor(.blue)
                }
            }
        } header: {
            Text("Account")
        } footer: {
            Text("If you previously purchased a Pro subscription, tap Restore Purchases to restore it on this device.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var isPro: Bool {
        entitlementManager.isProUser
    }
    
    private var statusText: String {
        if isPro {
            return "Pro"
        } else {
            return "Base"
        }
    }
    
    private var expirationText: String? {
        guard let status = subscriptionManager.subscriptionStatus else {
            return nil
        }
        
        if entitlementManager.isInFreeTrial {
            if let daysRemaining = entitlementManager.daysRemainingInTrial {
                return "Trial: \(daysRemaining) days left"
            }
        }
        
        if let expiration = status.expirationDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return "Renews on \(formatter.string(from: expiration))"
        }
        
        return nil
    }
    
    // MARK: - Actions
    
    private func openManageSubscriptions() async {
        await subscriptionManager.openManageSubscriptions()
        await subscriptionManager.updateSubscriptionStatus()
    }
    
    private func restorePurchases() async {
        let success = await subscriptionManager.restorePurchases()
        if !success {
            errorMessage = subscriptionManager.errorMessage ?? "Failed to restore purchases. Please try again."
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionManagementView()
    }
}
