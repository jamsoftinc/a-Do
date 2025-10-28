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
    case aiWritingTools = "ai_writing_tools"
    case advancedNLP = "advanced_nlp"
    case liveActivities = "live_activities"
    case visualIntelligence = "visual_intelligence"
    case interactiveWidgets = "interactive_widgets"
    case enhancedSiri = "enhanced_siri"
    case journalIntegration = "journal_integration"
    case sharePlay = "shareplay"
    case subtasks = "subtasks"
    case applePencilPro = "apple_pencil_pro"
    case translation = "translation"
    case advancedFocus = "advanced_focus"
    
    var displayName: String {
        switch self {
        case .aiWritingTools: return "AI Writing Tools"
        case .advancedNLP: return "Natural Language Processing"
        case .liveActivities: return "Live Activities"
        case .visualIntelligence: return "Visual Intelligence"
        case .interactiveWidgets: return "Interactive Widgets"
        case .enhancedSiri: return "Enhanced Siri"
        case .journalIntegration: return "Journal Integration"
        case .sharePlay: return "SharePlay"
        case .subtasks: return "Subtasks & Dependencies"
        case .applePencilPro: return "Apple Pencil Pro"
        case .translation: return "Translation"
        case .advancedFocus: return "Advanced Focus Mode"
        }
    }
    
    var description: String {
        switch self {
        case .aiWritingTools: return "Smart rewrite, proofread, and summarize your notes"
        case .advancedNLP: return "Parse complex reminder text with natural language"
        case .liveActivities: return "Track focus sessions in Dynamic Island"
        case .visualIntelligence: return "Scan documents and notes with your camera"
        case .interactiveWidgets: return "Complete tasks directly from widgets"
        case .enhancedSiri: return "Conversational shortcuts with Siri"
        case .journalIntegration: return "Auto-export accomplishments to Journal"
        case .sharePlay: return "Co-working sessions with friends"
        case .subtasks: return "Break down tasks with unlimited subtasks"
        case .applePencilPro: return "Hand-drawn sketches and squeeze gestures (iPad required)"
        case .translation: return "Auto-translate for collaboration"
        case .advancedFocus: return "Deep Focus Mode integration"
        }
    }
    
    var icon: String {
        switch self {
        case .aiWritingTools: return "sparkles.text.word.left"
        case .advancedNLP: return "text.bubble"
        case .liveActivities: return "island"
        case .visualIntelligence: return "camera.viewfinder"
        case .interactiveWidgets: return "square.3.stack.3d"
        case .enhancedSiri: return "mic.badge.plus"
        case .journalIntegration: return "book.closed"
        case .sharePlay: return "shareplay"
        case .subtasks: return "checklist"
        case .applePencilPro: return "pencil.tip"
        case .translation: return "character.bubble"
        case .advancedFocus: return "target"
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
