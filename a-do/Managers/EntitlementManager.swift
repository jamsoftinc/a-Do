//
//  EntitlementManager.swift
//  a-do
//
//  Feature entitlement checking
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class EntitlementManager {
    static let shared = EntitlementManager()
    
    private var subscriptionManager: SubscriptionManager
    
    private init() {
        self.subscriptionManager = SubscriptionManager.shared
    }
    
    // MARK: - Pro Access Check
    
    var isProUser: Bool {
        guard let status = subscriptionManager.subscriptionStatus else { return false }
        let isActive = status.isActive

        // Store Pro status in App Group UserDefaults for widget access
        if let sharedDefaults = UserDefaults(suiteName: "group.com.ado.app") {
            sharedDefaults.set(isActive, forKey: "isProUser")
            sharedDefaults.synchronize()
        }

        return isActive
    }
    
    var isInFreeTrial: Bool {
        return subscriptionManager.subscriptionStatus?.isInTrial ?? false
    }
    
    var daysRemainingInTrial: Int? {
        return subscriptionManager.subscriptionStatus?.daysRemainingInTrial
    }
    
    func hasAccess(to feature: ProFeature) -> Bool {
        return isProUser
    }
    
    // MARK: - Feature Gate Helpers
    
    func requirePro<T>(for feature: ProFeature, fallback: T) -> T {
        return hasAccess(to: feature) ? feature as! T : fallback
    }
    
    func canAccess<T>(feature: ProFeature, action: @escaping () -> T) -> T? {
        return hasAccess(to: feature) ? action() : nil
    }
    
    // MARK: - Upsell Prompt
    
    var shouldShowUpsell: Bool {
        return !isProUser
    }
    
    var subscriptionStatusText: String {
        guard let status = subscriptionManager.subscriptionStatus else {
            return "Base"
        }
        return status.displayStatus
    }
}

// MARK: - Pro Feature Gating

extension EntitlementManager {
    
    // Check individual features
    var canUseAIWritingTools: Bool {
        return hasAccess(to: .aiWritingTools)
    }
    
    var canUseAdvancedNLP: Bool {
        return hasAccess(to: .advancedNLP)
    }
    
    var canUseLiveActivities: Bool {
        return hasAccess(to: .liveActivities)
    }
    
    var canUseVisualIntelligence: Bool {
        return hasAccess(to: .visualIntelligence)
    }
    
    var canUseInteractiveWidgets: Bool {
        return hasAccess(to: .interactiveWidgets)
    }
    
    var canUseEnhancedSiri: Bool {
        return hasAccess(to: .enhancedSiri)
    }
    
    var canUseJournalIntegration: Bool {
        return hasAccess(to: .journalIntegration)
    }

    var canUseSharePlay: Bool {
        return hasAccess(to: .sharePlay)
    }
    
    var canUseSubtasks: Bool {
        return hasAccess(to: .subtasks)
    }
    
    var canUseApplePencilPro: Bool {
        return hasAccess(to: .applePencilPro)
    }
    
    var canUseTranslation: Bool {
        return hasAccess(to: .translation)
    }
    
    var canUseAdvancedFocus: Bool {
        return hasAccess(to: .advancedFocus)
    }
}
