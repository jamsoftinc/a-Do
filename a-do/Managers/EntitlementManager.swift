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

    // Core Pro Features
    var canUseAdvancedNLP: Bool {
        return hasAccess(to: .advancedNLP)
    }

    var canUseLiveActivities: Bool {
        return hasAccess(to: .liveActivities)
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

    // New Pro Features
    var canUseCalendarBlocking: Bool {
        return hasAccess(to: .calendarBlocking)
    }

    var canUseDailyPlanning: Bool {
        return hasAccess(to: .dailyPlanning)
    }

    var canUseBatchOperations: Bool {
        return hasAccess(to: .batchOperations)
    }

    var canUseVoiceReminders: Bool {
        return hasAccess(to: .voiceReminders)
    }

    var canUseSmartSnooze: Bool {
        return hasAccess(to: .smartSnooze)
    }

    var canUseRecurringReminders: Bool {
        return hasAccess(to: .recurringReminders)
    }

    var canUseSmartNotifications: Bool {
        return hasAccess(to: .smartNotifications)
    }

    // MARK: - Apple Intelligence Features

    var canUseAppleIntelligence: Bool {
        return hasAccess(to: .appleIntelligence)
    }

    var canUseFoundationModels: Bool {
        return hasAccess(to: .foundationModels)
    }

    var canUseVisualIntelligence: Bool {
        return hasAccess(to: .visualIntelligence)
    }

    var canUseWritingTools: Bool {
        return hasAccess(to: .writingTools)
    }

    var canUseAIWritingTools: Bool {
        return hasAccess(to: .writingTools)
    }

    var canUseSiriIntelligence: Bool {
        return hasAccess(to: .siriIntelligence)
    }

    var canUseSmartSuggestions: Bool {
        return hasAccess(to: .smartSuggestions)
    }

    var canUseContextualActions: Bool {
        return hasAccess(to: .contextualActions)
    }
}
