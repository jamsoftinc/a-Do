//
//  PaywallView.swift
//  a-do
//
//  Subscription paywall view
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let onDismiss: (() -> Void)?
    
    init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        headerSection
                        
                        // Features
                        featuresSection
                        
                        // Free Trial Section
                        freeTrialSection
                        
                        // Pricing Cards
                        pricingSection
                        
                        // Footer
                        footerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Unlock Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismissAction() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .task {
                await subscriptionManager.loadProducts()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary)
                    .frame(width: 80, height: 80)

                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            
            Text("Unlock All Pro Features")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("Get access to advanced pro level features.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pro Features")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            LazyVStack(spacing: 12) {
                ForEach(allProFeatures, id: \.rawValue) { feature in
                    featureRow(for: feature)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
        )
    }
    
    private var allProFeatures: [ProFeature] {
        ProFeature.allCases
    }
    
    private func featureRow(for feature: ProFeature) -> some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.title3)
                .foregroundStyle(AppTheme.Colors.primary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text(feature.description)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
    }
    
    // MARK: - Free Trial Section
    
    private var freeTrialSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "gift.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Your Free Trial")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Text("Free trial handled directly by App Store on eligible plans")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }

            if hasStoreIntroOffer {
                Text("Choose an eligible plan below. Apple applies your introductory trial automatically.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if subscriptionManager.availableProducts.isEmpty {
                Text("Loading App Store offers. Trial eligibility appears once products are available.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No introductory trial is currently available for this account.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            #if DEBUG
            Button {
                Task {
                    await startFreeTrial()
                }
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Free Trial")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous))
            }
            .buttonStyle(.plain)
            #endif
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
        )
    }
    
    // MARK: - Pricing Section
    
    private var pricingSection: some View {
        VStack(spacing: 16) {
            if subscriptionManager.availableProducts.isEmpty {
                // Show fallback pricing when StoreKit products aren't available
                ForEach(SubscriptionProduct.allProducts, id: \.id) { product in
                    fallbackPricingCard(for: product)
                }
            } else {
                // Show real StoreKit products when available
                ForEach(subscriptionManager.availableProducts, id: \.id) { product in
                    pricingCard(for: product)
                }
            }
        }
    }
    
    private func fallbackPricingCard(for product: SubscriptionProduct) -> some View {
        let isSelected = selectedProduct?.id == product.id
        
        return Button {
            Task {
                await attemptFallbackPurchase(for: product)
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(product.displayName)
                                .font(.headline)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            
                            if product.isPopular {
                                Text("POPULAR")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(product.price)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        
                        if let savings = product.savingsPercentage {
                            Text("Save \(savings)% per year")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        
                        Text("per \(product.subscriptionType == .annual ? "year" : "month")")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.Colors.primary)
                            .font(.title2)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .font(.title2)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppTheme.Colors.primary : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func pricingCard(for product: Product) -> some View {
        let isPopular = product.id == "com.ado.pro.annual"
        let isSelected = selectedProduct?.id == product.id
        
        return Button {
            selectedProduct = product
            Task {
                await purchaseProduct(product)
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(product.id.contains("annual") ? "Annual" : "Monthly")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            
                            if isPopular {
                                Text("POPULAR")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(product.localizedPrice)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        
                        if let savings = subscriptionType(for: product)?.savingsPercentage {
                            Text("Save \(savings)% per year")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else if product.id.contains("monthly") {
                            Text("per month")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                }

                if isPopular {
                    Divider()
                        .background(AppTheme.Colors.surfaceLight)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("Best Value")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(16)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.Colors.primary.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.Colors.primary, lineWidth: 2)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.Colors.surface)
                }
            }
        }
        .disabled(isPurchasing)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 16) {
            // Continue without Pro button
            Button(action: { dismissAction() }) {
                Text("Continue with Base Version")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            
            // Terms and restore
            HStack(spacing: 24) {
                Button("Terms of Service") {
                    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                
                Button("Privacy Policy") {
                    if let url = URL(string: "https://jamsoftinc.com/privacy-policy") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                
                Button("Restore Purchases") {
                    Task {
                        await restorePurchases()
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func subscriptionType(for product: Product) -> SubscriptionType? {
        if product.id.contains("annual") {
            return .annual
        } else if product.id.contains("monthly") {
            return .monthly
        }
        return nil
    }

    private var hasStoreIntroOffer: Bool {
        subscriptionManager.availableProducts.contains { $0.subscription?.introductoryOffer != nil }
    }
    
    private func purchaseProduct(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        let success = await subscriptionManager.purchase(product)
        
        if success {
            dismissAction()
        } else if subscriptionManager.purchaseState == .failed {
            errorMessage = subscriptionManager.errorMessage ?? "Purchase failed. Please try again."
            showError = true
        }
    }
    
    private func restorePurchases() async {
        let success = await subscriptionManager.restorePurchases()
        if success {
            dismissAction()
        }
    }
    
    private func startFreeTrial() async {
        // Start the 7-day free trial
        subscriptionManager.startFreeTrial(context: context)
        if let error = subscriptionManager.errorMessage {
            errorMessage = error
            showError = true
        } else {
            dismissAction()
        }
    }

    private func attemptFallbackPurchase(for product: SubscriptionProduct) async {
        selectedProduct = nil
        isPurchasing = true
        defer { isPurchasing = false }

        if subscriptionManager.availableProducts.isEmpty {
            await subscriptionManager.loadProducts()
        }

        if let liveProduct = subscriptionManager.availableProducts.first(where: { $0.id == product.id }) {
            await purchaseProduct(liveProduct)
            return
        }

        if product.subscriptionType == .monthly || product.subscriptionType == .annual {
            errorMessage = "Store products are temporarily unavailable. Please try again in a moment."
            showError = true
        }
    }
    
    private func dismissAction() {
        dismiss()
        onDismiss?()
    }

    private func goHome() {
        NotificationCenter.default.post(name: .appNavigateHome, object: nil)
        dismissAction()
    }
}

#Preview {
    PaywallView()
}
