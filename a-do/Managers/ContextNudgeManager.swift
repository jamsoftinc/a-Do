//
//  ContextNudgeManager.swift
//  a-do
//
//  Created for iOS 26+ Smart Context Nudges
//

import Foundation
import SwiftData
import Observation
import os
import CoreLocation
import UserNotifications

enum UserContextType: String, CaseIterable, Codable {
    case gym
    case library
    case office
    case home
    case focusZone
}

@MainActor
@Observable
final class ContextNudgeManager: NSObject {
    static let shared = ContextNudgeManager()
    
    private let logger = Logger(subsystem: "a-do", category: "ContextNudges")
    private let locationManager = LocationManager.shared
    
    // Pro Feature Check
    var isProEnabled: Bool {
        return EntitlementManager.shared.isProUser
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - Simulation / Trigger
    
    func simulateContext(_ context: UserContextType, modelContext: ModelContext) {
        guard isProEnabled else {
            logger.warning("Context Nudges are a Pro feature")
            return
        }
        
        logger.info("Simulating context entry: \(context.rawValue)")
        
        switch context {
        case .gym:
            triggerNudge(
                title: "Workout Detected",
                body: "You seem to be at the gym. Start an 'Exercise' Focus?",
                focusType: .exercise,
                context: modelContext
            )
        case .library, .focusZone:
            triggerNudge(
                title: "Quiet Zone",
                body: "Perfect time for deep work. Start a 'Study' session?",
                focusType: .study,
                context: modelContext
            )
        case .office:
            triggerNudge(
                title: "At the Office",
                body: "Ready to log in? Start a 'Work' session.",
                focusType: .work,
                context: modelContext
            )
        default:
            break
        }
    }
    
    // MARK: - Notification Logic
    
    private func triggerNudge(title: String, body: String, focusType: FocusType, context: ModelContext) {
        // In a real implementation, we would use SmartNotificationManager to schedule this.
        // For now, we'll create a new SmartNotification record which the system would pick up.
        
        let notification = SmartNotification(
            userId: "current-user",
            type: .aiSuggestion, // or focusStart
            title: title,
            body: body,
            scheduledDate: Date().addingTimeInterval(5) // Immediate trigger
        )
        notification.priority = .high
        notification.context = .general // Could be .gym, etc.
        
        context.insert(notification)
        
        do {
            try context.save()
            logger.info("Scheduled Context Nudge: \(title)")
            
            // Post a local notification via UserNotifications for immediate feedback if permission exists
            sendLocalNotification(title: title, body: body)
            
        } catch {
            logger.error("Failed to save nudge: \(error.localizedDescription)")
        }
    }
    
    private func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
