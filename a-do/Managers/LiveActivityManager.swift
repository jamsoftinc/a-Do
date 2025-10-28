//
//  LiveActivityManager.swift
//  a-do
//
//  Live Activities and Dynamic Island integration for iOS 26
//

import Foundation
import ActivityKit
import WidgetKit
import Observation
import os

@MainActor
@Observable
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private let logger = Logger(subsystem: "a-do", category: "LiveActivity")
    
    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.canUseLiveActivities
    }
    
    private init() {}
    
    // MARK: - Focus Session Activity
    
    func startFocusSessionActivity(session: FocusSession) {
        guard isProEnabled else {
            logger.warning("Live Activities is a Pro feature")
            return
        }
        
        logger.info("Starting Live Activity for focus session: \(session.name)")
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Live Activities are not enabled")
            return
        }
        
        let activityContent = ActivityContent(
            state: FocusActivityAttributes.ContentState(
                sessionName: session.name,
                remainingTime: session.remainingTime,
                totalTime: session.plannedDuration,
                isActive: session.isActive,
                isOnBreak: false
            ),
            staleDate: Date().addingTimeInterval(session.remainingTime)
        )
        
        let activityAttributes = FocusActivityAttributes()
        
        do {
            let activity = try Activity<FocusActivityAttributes>.request(
                attributes: activityAttributes,
                content: activityContent,
                pushType: nil
            )
            
            logger.info("Live Activity started: \(activity.id)")
            
            // Store activity ID for updates
            storeActivityID(activity.id, for: session.id)
            
        } catch {
            logger.error("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    func updateFocusSessionActivity(session: FocusSession) {
        guard let activity = getActivity(for: session.id) else {
            logger.warning("No activity found for session: \(session.id)")
            return
        }
        
        let newState = FocusActivityAttributes.ContentState(
            sessionName: session.name,
            remainingTime: session.remainingTime,
            totalTime: session.plannedDuration,
            isActive: session.isActive,
            isOnBreak: false
        )

        let content = ActivityContent(
            state: newState,
            staleDate: Date().addingTimeInterval(session.remainingTime)
        )

        Task {
            await activity.update(content)
        }
    }
    
    func endFocusSessionActivity(session: FocusSession) {
        guard let activity = getActivity(for: session.id) else {
            logger.warning("No activity found for session: \(session.id)")
            return
        }
        
        let finalState = FocusActivityAttributes.ContentState(
            sessionName: session.name,
            remainingTime: 0,
            totalTime: session.plannedDuration,
            isActive: false,
            isOnBreak: false
        )

        let content = ActivityContent(
            state: finalState,
            staleDate: Date()
        )

        Task {
            await activity.end(content, dismissalPolicy: .immediate)
        }
        
        removeActivityID(for: session.id)
    }
    
    // MARK: - Helper Methods
    
    private func storeActivityID(_ activityID: String, for sessionID: UUID) {
        UserDefaults.standard.set(activityID, forKey: "focus_activity_\(sessionID.uuidString)")
    }
    
    private func getActivityID(for sessionID: UUID) -> String? {
        return UserDefaults.standard.string(forKey: "focus_activity_\(sessionID.uuidString)")
    }
    
    private func removeActivityID(for sessionID: UUID) {
        UserDefaults.standard.removeObject(forKey: "focus_activity_\(sessionID.uuidString)")
    }
    
    private func getActivity(for sessionID: UUID) -> Activity<FocusActivityAttributes>? {
        guard let activityID = getActivityID(for: sessionID) else { return nil }
        
        let activities = Activity<FocusActivityAttributes>.activities
        return activities.first { $0.id == activityID }
    }
}

// MARK: - Activity Attributes

struct FocusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var sessionName: String
        var remainingTime: TimeInterval
        var totalTime: TimeInterval
        var isActive: Bool
        var isOnBreak: Bool
        
        var progress: Double {
            guard totalTime > 0 else { return 0 }
            let elapsed = totalTime - remainingTime
            return min(1.0, elapsed / totalTime)
        }
        
        var remainingMinutes: Int {
            return Int(remainingTime / 60)
        }
        
        var remainingSeconds: Int {
            return Int(remainingTime.truncatingRemainder(dividingBy: 60))
        }
    }
    
    var name: String = "Focus Session"
}
