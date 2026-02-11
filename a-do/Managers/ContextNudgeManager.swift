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
    
    // MARK: - Context Triggering
    
    func handleContextEvent(_ context: UserContextType, modelContext: ModelContext) {
        guard isProEnabled else {
            logger.warning("Context Nudges are a Pro feature")
            return
        }
        
        logger.info("Processing context event: \(context.rawValue)")
        
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
        case .home:
            break
        }
    }
    
    func evaluateCurrentContextAndTrigger(modelContext: ModelContext) async {
        guard isProEnabled else { return }
        
        if let location = await locationManager.getCurrentLocation() {
            let context = classifyContext(from: location)
            handleContextEvent(context, modelContext: modelContext)
            return
        }
        
        // Fallback to time-of-day context if location is unavailable.
        let hour = Calendar.current.component(.hour, from: Date())
        if (6..<9).contains(hour) || (18..<21).contains(hour) {
            handleContextEvent(.home, modelContext: modelContext)
        } else if (9..<17).contains(hour) {
            handleContextEvent(.office, modelContext: modelContext)
        }
    }
    
    // MARK: - Notification Logic
    
    private func triggerNudge(title: String, body: String, focusType: FocusType, context: ModelContext) {
        let notification = SmartNotification(
            userId: SecurityUtils.getCurrentUserID(),
            type: .aiSuggestion, // or focusStart
            title: title,
            body: body,
            scheduledDate: Date().addingTimeInterval(5)
        )
        notification.priority = .high
        notification.context = mapFocusTypeToNotificationContext(focusType)
        
        context.insert(notification)
        
        do {
            try context.save()
            logger.info("Scheduled Context Nudge: \(title)")
            
            sendLocalNotification(title: title, body: body)
            
        } catch {
            logger.error("Failed to save nudge: \(error.localizedDescription)")
        }
    }
    
    private func classifyContext(from location: CLLocation) -> UserContextType {
        let speed = max(0, location.speed)
        
        if speed > 5.0 {
            return .focusZone
        }
        
        if let address = locationManager.currentAddress?.lowercased() {
            if address.contains("gym") || address.contains("fitness") {
                return .gym
            }
            if address.contains("office") || address.contains("work") {
                return .office
            }
            if address.contains("library") {
                return .library
            }
            if address.contains("home") {
                return .home
            }
        }
        
        return .focusZone
    }
    
    private func mapFocusTypeToNotificationContext(_ focusType: FocusType) -> NotificationContext {
        switch focusType {
        case .work:
            return .work
        case .study:
            return .focus
        case .exercise:
            return .health
        case .personal:
            return .personal
        default:
            return .general
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
