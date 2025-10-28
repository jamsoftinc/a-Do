//
//  SubscriptionManager.swift
//  a-do
//
//  StoreKit 2 subscription management
//

import Foundation
import StoreKit
import SwiftData
import Observation
import os

@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()
    
    private let logger = Logger(subsystem: "a-do", category: "Subscription")
    
    // State
    var availableProducts: [Product] = []
    var purchaseState: PurchaseState = .idle
    var subscriptionStatus: SubscriptionStatus?
    var isLoading: Bool = false
    var errorMessage: String?
    
    // Transaction listener
    private var updateListenerTask: Task<Void, Error>?
    
    enum PurchaseState {
        case idle
        case purchasing
        case purchased
        case failed
        case cancelled
    }
    
    private init() {
        // Initialize subscription status
        self.subscriptionStatus = SubscriptionStatus(userId: "current-user")

        startTransactionListener()

        // Check for existing subscriptions on launch
        Task {
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        // Cancel listener task on deinit
        // Note: accessing main actor isolated property from deinit
        Task { @MainActor in
            updateListenerTask?.cancel()
        }
    }
    
    // MARK: - Initialization
    
    func loadProducts() async {
        logger.info("Loading subscription products...")
        isLoading = true
        errorMessage = nil
        
        do {
            let productIds = SubscriptionProduct.allProducts.map { $0.id }
            let products = try await Product.products(for: productIds)
            
            // Sort products: annual first (popular), then monthly
            let sortedProducts = products.sorted { first, second in
                if first.id == "com.ado.pro.annual" { return true }
                if second.id == "com.ado.pro.annual" { return false }
                return first.id < second.id
            }
            
            await MainActor.run {
                self.availableProducts = sortedProducts
                self.isLoading = false
                logger.info("Loaded \(sortedProducts.count) products")
            }
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async -> Bool {
        logger.info("Starting purchase for: \(product.id)")
        purchaseState = .purchasing
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                logger.info("Purchase successful, verifying transaction...")
                let transaction = try checkVerificationResult(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
                
                purchaseState = .purchased
                logger.info("Purchase completed successfully")
                return true
                
            case .userCancelled:
                logger.info("User cancelled purchase")
                purchaseState = .cancelled
                return false
                
            case .pending:
                logger.info("Purchase is pending")
                purchaseState = .idle
                // Handle pending transactions later
                return false
                
            @unknown default:
                logger.error("Unknown purchase result")
                purchaseState = .failed
                return false
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            purchaseState = .failed
            return false
        }
    }
    
    // MARK: - Transaction Listener
    
    private func startTransactionListener() {
        updateListenerTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handleTransactionUpdate(result)
            }
        }
    }
    
    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerificationResult(result)
            
            logger.info("Processing transaction update: \(transaction.productID)")
            
            // Update subscription status
            await updateSubscriptionStatus()
            
            // Finish the transaction
            await transaction.finish()
        } catch {
            logger.error("Transaction verification failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Subscription Status
    
    func updateSubscriptionStatus() async {
        logger.info("Updating subscription status...")
        
        do {
            var currentEntitlement: Transaction?
            var highestTransaction: Transaction?
            
            // Check all active subscriptions
            for await result in Transaction.currentEntitlements {
                let transaction = try checkVerificationResult(result)
                
                // Track the most recent subscription
                if highestTransaction == nil || transaction.purchaseDate > highestTransaction!.purchaseDate {
                    highestTransaction = transaction
                }
                
                currentEntitlement = transaction
            }
            
            await updateLocalSubscriptionStatus(from: highestTransaction)
            
        } catch {
            logger.error("Failed to update subscription status: \(error.localizedDescription)")
        }
    }
    
    private func updateLocalSubscriptionStatus(from transaction: Transaction?) async {
        await MainActor.run {
            // Ensure subscription status exists
            if self.subscriptionStatus == nil {
                self.subscriptionStatus = SubscriptionStatus(userId: "current-user")
            }

            guard let transaction = transaction else {
                // No active subscription
                self.subscriptionStatus?.isProSubscriber = false
                self.subscriptionStatus?.subscriptionType = nil
                self.subscriptionStatus?.expirationDate = nil
                return
            }
            
            // Parse product ID to determine subscription type
            let subscriptionType: SubscriptionType?
            if transaction.productID.contains("monthly") {
                subscriptionType = .monthly
            } else if transaction.productID.contains("annual") {
                subscriptionType = .annual
            } else {
                subscriptionType = nil
            }
            
            // Calculate expiration date
            let expirationDate: Date?
            if let expirationDateValue = transaction.expirationDate {
                expirationDate = expirationDateValue
            } else {
                // Calculate based on purchase date and subscription type
                let calendar = Calendar.current
                if transaction.productID.contains("monthly") {
                    expirationDate = calendar.date(byAdding: .month, value: 1, to: transaction.purchaseDate)
                } else if transaction.productID.contains("annual") {
                    expirationDate = calendar.date(byAdding: .year, value: 1, to: transaction.purchaseDate)
                } else {
                    expirationDate = nil
                }
            }
            
            // Check if user is in trial period
            let isInTrial = transaction.offerType == .introductory
            let trialEndDate = isInTrial ? expirationDate : nil

            self.subscriptionStatus?.isProSubscriber = true
            self.subscriptionStatus?.subscriptionType = subscriptionType
            self.subscriptionStatus?.expirationDate = expirationDate
            self.subscriptionStatus?.purchaseDate = transaction.purchaseDate
            self.subscriptionStatus?.originalTransactionId = String(transaction.originalID)
            self.subscriptionStatus?.productId = transaction.productID
            self.subscriptionStatus?.lastVerifiedDate = Date()
            self.subscriptionStatus?.isInTrial = isInTrial
            self.subscriptionStatus?.trialEndDate = trialEndDate

            let statusText = isInTrial ? "trial" : "active"
            logger.info("Subscription status updated: \(subscriptionType?.displayName ?? "unknown") (\(statusText)) until \(expirationDate?.formatted() ?? "unknown")")
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async -> Bool {
        logger.info("Restoring purchases...")
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            
            logger.info("Purchases restored successfully")
            return true
        } catch {
            logger.error("Failed to restore purchases: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Subscription Management
    
    func openManageSubscriptions() async {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            logger.error("No window scene available")
            return
        }
        
        do {
            try await AppStore.showManageSubscriptions(in: windowScene)
            // Update status after user potentially modifies subscription
            await updateSubscriptionStatus()
        } catch {
            logger.error("Failed to open manage subscriptions: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Free Trial
    
    func startFreeTrial(context: ModelContext) {
        logger.info("Starting 7-day free trial...")
        
        let calendar = Calendar.current
        guard let trialEndDate = calendar.date(byAdding: .day, value: 7, to: Date()) else {
            logger.error("Failed to calculate trial end date")
            return
        }
        
        subscriptionStatus?.isProSubscriber = true
        subscriptionStatus?.isInTrial = true
        subscriptionStatus?.trialEndDate = trialEndDate
        // Note: subscriptionType will be set when user chooses their plan after trial
        
        do {
            try context.save()
            logger.info("Free trial started until \(trialEndDate.formatted())")
        } catch {
            logger.error("Failed to save trial status: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkVerificationResult<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Product Lookup
    
    func product(for subscriptionType: SubscriptionType) -> Product? {
        return availableProducts.first { $0.id == subscriptionType.productId }
    }
}

// MARK: - Extensions

extension Product {
    var localizedPrice: String {
        return self.displayPrice
    }
}

// Transaction.expirationDate is already a property, no need to override
