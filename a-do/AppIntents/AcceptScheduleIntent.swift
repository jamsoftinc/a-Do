//
//  AcceptScheduleIntent.swift
//  a-do
//
//  Created for iOS 26+ Morning Briefing Feature
//

import AppIntents
import SwiftUI

struct AcceptScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "Accept Schedule"
    static var description: IntentDescription = "Accepts the morning briefing schedule and starts the day."
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // 1. Mark briefing as read
        MorningBriefingManager.shared.markBriefingAsRead()
        
        // 2. Optionally start the first focus session or navigate to Today view
        // Logic to navigate would typically be handled by the AppRouter observing a state change
        // derived from MorningBriefingManager
        
        return .result(dialog: "Schedule accepted. Let's get to work!")
    }
}
