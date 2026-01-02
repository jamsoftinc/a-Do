//
//  SubscriptionModels.swift
//  a-do
//
//  Subscription and Pro features models
//

import Foundation
import SwiftData

// MARK: - Subscription Status Model

@Model
final class SubscriptionStatus {
    var id: UUID = UUID()
    var userId: String = ""
    var isProSubscriber: Bool = false
    var subscriptionTypeRaw: String?
    var expirationDate: Date?
    var trialEndDate: Date?
    var isInTrial: Bool = false
    var purchaseDate: Date?
    var originalTransactionId: String?
    var productId: String?
    var lastVerifiedDate: Date = Date()
    var autoRenewEnabled: Bool = true
    
    var subscriptionType: SubscriptionType? {
        get {
            guard let typeRaw = subscriptionTypeRaw else { return nil }
            return SubscriptionType(rawValue: typeRaw)
        }
        set {
            subscriptionTypeRaw = newValue?.rawValue
        }
    }
    
    init(userId: String) {
        self.userId = userId
        self.lastVerifiedDate = Date()
    }
    
    // MARK: - Computed Properties
    
    var isActive: Bool {
        guard isProSubscriber else { return false }
        
        // Check if in trial period
        if isInTrial, let trialEnd = trialEndDate {
            return Date() <= trialEnd
        }
        
        // Check if subscription is valid
        if let expiration = expirationDate {
            return Date() <= expiration
        }
        
        return isProSubscriber
    }
    
    var daysRemainingInTrial: Int? {
        guard isInTrial, let trialEnd = trialEndDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: trialEnd)
        guard let days = components.day else { return nil }
        return max(0, days)
    }
    
    var displayStatus: String {
        if !isProSubscriber {
            return "Base"
        }
        
        if isInTrial, let daysRemaining = daysRemainingInTrial {
            return "Trial (\(daysRemaining) days remaining)"
        }
        
        if let expiration = expirationDate {
            if expiration < Date() {
                return "Expired"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                return "Pro until \(formatter.string(from: expiration))"
            }
        }
        
        return "Pro"
    }
}

// MARK: - Subscription Type

enum SubscriptionType: String, CaseIterable, Codable {
    case monthly = "monthly"
    case annual = "annual"
    
    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        }
    }
    
    var productId: String {
        switch self {
        case .monthly: return "com.ado.pro.monthly"
        case .annual: return "com.ado.pro.annual"
        }
    }
    
    var priceFormatted: String {
        switch self {
        case .monthly: return "$2.99/month"
        case .annual: return "$19.99/year"
        }
    }
    
    var monthlyEquivalent: Double {
        switch self {
        case .monthly: return 2.99
        case .annual: return 19.99 / 12.0
        }
    }
    
    var savingsPercentage: Int? {
        switch self {
        case .monthly: return nil
        case .annual: return 33
        }
    }
}

// MARK: - Pro Feature

enum ProFeature: String, CaseIterable, Codable {
    // Core Pro Features
    case advancedNLP = "advanced_nlp"
    case liveActivities = "live_activities"
    case interactiveWidgets = "interactive_widgets"
    case enhancedSiri = "enhanced_siri"
    case journalIntegration = "journal_integration"
    case subtasks = "subtasks"
    case applePencilPro = "apple_pencil_pro"
    case translation = "translation"
    case advancedFocus = "advanced_focus"

    // New Pro Features
    case calendarBlocking = "calendar_blocking"
    case dailyPlanning = "daily_planning"
    case batchOperations = "batch_operations"
    case voiceReminders = "voice_reminders"
    case smartSnooze = "smart_snooze"
    case recurringReminders = "recurring_reminders"
    case smartNotifications = "smart_notifications"

    // Apple Intelligence Features
    case appleIntelligence = "apple_intelligence"
    case foundationModels = "foundation_models"
    case visualIntelligence = "visual_intelligence"
    case writingTools = "writing_tools"
    case siriIntelligence = "siri_intelligence"
    case smartSuggestions = "smart_suggestions"
    case contextualActions = "contextual_actions"

    var displayName: String {
        switch self {
        case .advancedNLP: return "Natural Language Processing"
        case .liveActivities: return "Live Activities"
        case .interactiveWidgets: return "Interactive Widgets"
        case .enhancedSiri: return "Enhanced Siri"
        case .journalIntegration: return "Journal Integration"
        case .subtasks: return "Subtasks & Dependencies"
        case .applePencilPro: return "Apple Pencil Pro"
        case .translation: return "Translation"
        case .advancedFocus: return "Advanced Focus Mode"
        case .calendarBlocking: return "Calendar Blocking"
        case .dailyPlanning: return "Daily Planning"
        case .batchOperations: return "Batch Operations"
        case .voiceReminders: return "Voice Reminders"
        case .smartSnooze: return "Smart Snooze"
        case .recurringReminders: return "Advanced Recurring"
        case .smartNotifications: return "Smart Notifications"
        case .appleIntelligence: return "Apple Intelligence"
        case .foundationModels: return "On-Device AI"
        case .visualIntelligence: return "Visual Intelligence"
        case .writingTools: return "Writing Tools"
        case .siriIntelligence: return "Siri Intelligence"
        case .smartSuggestions: return "Smart Suggestions"
        case .contextualActions: return "Contextual Actions"
        }
    }

    var description: String {
        switch self {
        case .advancedNLP: return "Parse complex reminder text with natural language"
        case .liveActivities: return "Track focus sessions in Dynamic Island"
        case .interactiveWidgets: return "Complete tasks directly from widgets"
        case .enhancedSiri: return "Conversational shortcuts with Siri"
        case .journalIntegration: return "Auto-export accomplishments to Journal"
        case .subtasks: return "Break down tasks with unlimited subtasks"
        case .applePencilPro: return "Hand-drawn sketches and squeeze gestures"
        case .translation: return "Auto-translate for collaboration"
        case .advancedFocus: return "Deep Focus Mode integration"
        case .calendarBlocking: return "Block time on your calendar for tasks"
        case .dailyPlanning: return "Morning briefing and daily schedule view"
        case .batchOperations: return "Complete, move, or reschedule multiple tasks at once"
        case .voiceReminders: return "Create reminders with voice and live transcription"
        case .smartSnooze: return "AI-suggested snooze times based on your schedule"
        case .recurringReminders: return "Advanced recurring patterns and auto-generation"
        case .smartNotifications: return "Optimal notification timing based on context"
        case .appleIntelligence: return "Access all Apple Intelligence features for enhanced productivity"
        case .foundationModels: return "On-device AI for task parsing, breakdown, and insights"
        case .visualIntelligence: return "Scan documents and images to create reminders"
        case .writingTools: return "AI-powered writing assistance for descriptions"
        case .siriIntelligence: return "Enhanced Siri with context-aware responses"
        case .smartSuggestions: return "AI-powered suggestions for due dates and priorities"
        case .contextualActions: return "Context-aware quick actions based on your activity"
        }
    }

    var icon: String {
        switch self {
        case .advancedNLP: return "text.bubble"
        case .liveActivities: return "platter.filled.top.and.arrow.up.iphone"
        case .interactiveWidgets: return "square.3.stack.3d"
        case .enhancedSiri: return "mic.badge.plus"
        case .journalIntegration: return "book.closed"
        case .subtasks: return "checklist"
        case .applePencilPro: return "pencil.tip"
        case .translation: return "character.bubble"
        case .advancedFocus: return "target"
        case .calendarBlocking: return "calendar.badge.clock"
        case .dailyPlanning: return "sun.max.fill"
        case .batchOperations: return "square.stack.3d.up"
        case .voiceReminders: return "waveform"
        case .smartSnooze: return "clock.badge.questionmark"
        case .recurringReminders: return "arrow.clockwise"
        case .smartNotifications: return "bell.badge.clock"
        case .appleIntelligence: return "apple.intelligence"
        case .foundationModels: return "brain"
        case .visualIntelligence: return "eye"
        case .writingTools: return "pencil.and.outline"
        case .siriIntelligence: return "mic.badge.plus"
        case .smartSuggestions: return "sparkles"
        case .contextualActions: return "wand.and.stars"
        }
    }
}

// MARK: - Subscription Product

struct SubscriptionProduct {
    let id: String
    let displayName: String
    let price: String
    let monthlyEquivalent: Double
    let savingsPercentage: Int?
    let subscriptionType: SubscriptionType
    let isPopular: Bool
    
    static let monthly = SubscriptionProduct(
        id: "com.ado.pro.monthly",
        displayName: "Monthly",
        price: "$2.99",
        monthlyEquivalent: 2.99,
        savingsPercentage: nil,
        subscriptionType: .monthly,
        isPopular: false
    )
    
    static let annual = SubscriptionProduct(
        id: "com.ado.pro.annual",
        displayName: "Annual",
        price: "$19.99",
        monthlyEquivalent: 1.67,
        savingsPercentage: 44,
        subscriptionType: .annual,
        isPopular: true
    )
    
    static var allProducts: [SubscriptionProduct] {
        [.annual, .monthly]
    }
}
