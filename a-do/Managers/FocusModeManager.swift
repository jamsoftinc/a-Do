//
//  FocusModeManager.swift
//  a-do
//
//  Focus mode and productivity session manager
//

import Foundation
import SwiftData
import Observation
import os
import UserNotifications

@MainActor
@Observable
final class FocusModeManager {
    static let shared = FocusModeManager()
    
    private let logger = Logger(subsystem: "a-do", category: "FocusMode")
    private let behavioralLearning = BehavioralLearningManager.shared
    
    // Current session state
    var currentSession: FocusSession?
    var isSessionActive: Bool = false
    var sessionTimeRemaining: TimeInterval = 0
    var isOnBreak: Bool = false
    var currentBreak: FocusBreak?
    
    // Timer management
    nonisolated(unsafe) private var sessionTimer: Timer?
    nonisolated(unsafe) private var breakTimer: Timer?
    
    // Statistics
    var todaysFocusTime: TimeInterval = 0
    var todaysSessionCount: Int = 0
    var currentStreak: Int = 0
    
    private init() {
        setupNotificationHandling()
    }
    
    nonisolated deinit {
        stopAllTimers()
    }
    
    // MARK: - Session Management
    
    func startSession(template: FocusTemplate, reminders: [Reminder] = [], context: ModelContext) {
        // End any existing session
        if let existing = currentSession, existing.isActive {
            endSession(context: context)
        }
        
        let session = template.createSession()
        session.focusedReminders = reminders
        session.start()
        
        currentSession = session
        isSessionActive = true
        sessionTimeRemaining = session.plannedDuration
        
        context.insert(session)
        
        // Start timer
        startSessionTimer()
        
        // Configure system focus mode
        configureSystemFocusMode(for: session)
        
        // Schedule notifications
        scheduleSessionNotifications(for: session)
        
        do {
            try context.save()
            logger.info("Started focus session: \(session.name)")
        } catch {
            logger.error("Failed to start session: \(error.localizedDescription)")
        }
    }
    
    func pauseSession(context: ModelContext) {
        guard let session = currentSession, session.isActive else { return }
        
        session.pause()
        isSessionActive = false
        stopSessionTimer()
        
        do {
            try context.save()
            logger.info("Paused focus session")
        } catch {
            logger.error("Failed to pause session: \(error.localizedDescription)")
        }
    }
    
    func resumeSession(context: ModelContext) {
        guard let session = currentSession, !session.isActive else { return }
        
        session.resume()
        isSessionActive = true
        sessionTimeRemaining = session.remainingTime
        startSessionTimer()
        
        do {
            try context.save()
            logger.info("Resumed focus session")
        } catch {
            logger.error("Failed to resume session: \(error.localizedDescription)")
        }
    }
    
    func endSession(context: ModelContext) {
        guard let session = currentSession else { return }
        
        session.complete()
        isSessionActive = false
        stopSessionTimer()
        
        // Calculate session effectiveness based on completion and interruptions
        let effectiveness = calculateSessionEffectiveness(session: session)
        
        // Track focus session for behavioral learning
        behavioralLearning.trackFocusSession(
            session: session,
            effectiveness: effectiveness,
            modelContext: context
        )
        
        // Update statistics
        updateDailyStatistics(session: session, context: context)
        
        // Clear system focus mode
        clearSystemFocusMode()
        
        // Cancel notifications
        cancelSessionNotifications()
        
        do {
            try context.save()
            logger.info("Ended focus session: \(session.name)")
        } catch {
            logger.error("Failed to end session: \(error.localizedDescription)")
        }
        
        currentSession = nil
        sessionTimeRemaining = 0
    }
    
    func recordInterruption(reason: InterruptionReason, context: ModelContext) {
        guard let session = currentSession else { return }
        
        session.interrupt(reason: reason)
        
        do {
            try context.save()
            logger.info("Recorded interruption: \(reason.displayName)")
        } catch {
            logger.error("Failed to record interruption: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Effectiveness Calculation
    
    private func calculateSessionEffectiveness(session: FocusSession) -> Double {
        // Calculate effectiveness based on multiple factors
        let completionRate = session.actualDuration / session.plannedDuration
        let interruptionPenalty = max(0, 1.0 - (Double(session.interruptionCount) * 0.1))
        let focusScore = session.productivityScore / 100.0 // Convert to 0-1 range
        
        // Weighted average of factors
        let effectiveness = (completionRate * 0.4) + (interruptionPenalty * 0.3) + (focusScore * 0.3)
        
        return min(1.0, max(0.0, effectiveness))
    }
    
    // MARK: - Break Management
    
    func startBreak(type: BreakType, duration: TimeInterval? = nil, context: ModelContext) {
        guard let session = currentSession else { return }
        
        let breakDuration = duration ?? type.defaultDuration
        let focusBreak = FocusBreak(type: type, duration: breakDuration, session: session)
        session.addBreak(type: type, duration: breakDuration)
        
        currentBreak = focusBreak
        isOnBreak = true
        
        // Pause session timer and start break timer
        pauseSession(context: context)
        startBreakTimer(duration: breakDuration)
        
        do {
            try context.save()
            logger.info("Started \(type.displayName) for \(Int(breakDuration/60)) minutes")
        } catch {
            logger.error("Failed to start break: \(error.localizedDescription)")
        }
    }
    
    func endBreak(context: ModelContext) {
        guard let focusBreak = currentBreak else { return }
        
        focusBreak.complete()
        currentBreak = nil
        isOnBreak = false
        stopBreakTimer()
        
        // Resume session if it was active
        if let session = currentSession, !session.wasCompleted {
            resumeSession(context: context)
        }
        
        do {
            try context.save()
            logger.info("Ended break")
        } catch {
            logger.error("Failed to end break: \(error.localizedDescription)")
        }
    }
    
    func skipBreak(context: ModelContext) {
        guard let focusBreak = currentBreak else { return }
        
        focusBreak.skip()
        currentBreak = nil
        isOnBreak = false
        stopBreakTimer()
        
        // Resume session
        if let session = currentSession, !session.wasCompleted {
            resumeSession(context: context)
        }
        
        do {
            try context.save()
            logger.info("Skipped break")
        } catch {
            logger.error("Failed to skip break: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Timer Management
    
    private func startSessionTimer() {
        stopSessionTimer()
        
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSessionTimer()
            }
        }
    }
    
    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }
    
    private func startBreakTimer(duration: TimeInterval) {
        stopBreakTimer()
        
        var remainingTime = duration
        
        breakTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                remainingTime -= 1
                
                if remainingTime <= 0 {
                    timer.invalidate()
                    self?.breakTimerExpired()
                }
            }
        }
    }
    
    private func stopBreakTimer() {
        breakTimer?.invalidate()
        breakTimer = nil
    }
    
    private func updateSessionTimer() {
        guard let session = currentSession, session.isActive else { return }
        
        sessionTimeRemaining = session.remainingTime
        
        if sessionTimeRemaining <= 0 {
            sessionTimerExpired()
        }
    }
    
    private func sessionTimerExpired() {
        logger.info("Focus session timer expired")
        
        // Send completion notification
        sendSessionCompletionNotification()
        
        // Suggest break if enabled
        if currentSession?.includeBreaks == true {
            suggestBreak()
        }
    }
    
    private func breakTimerExpired() {
        logger.info("Break timer expired")
        
        // Send break completion notification
        sendBreakCompletionNotification()
    }
    
    nonisolated private func stopAllTimers() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        breakTimer?.invalidate()
        breakTimer = nil
    }
    
    // MARK: - Reminder Integration
    
    func selectRemindersForSession(template: FocusTemplate, context: ModelContext) -> [Reminder] {
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { !$0.isCompleted }
        )
        
        let allReminders = (try? context.fetch(descriptor)) ?? []
        var selectedReminders: [Reminder] = []
        
        // Apply filters based on template settings
        for reminder in allReminders {
            var shouldInclude = false
            
            // High priority filter
            if template.includeHighPriority && reminder.priority == .high {
                shouldInclude = true
            }
            
            // Due today filter
            if template.includeDueToday, let dueDate = reminder.dueDate {
                if Calendar.current.isDateInToday(dueDate) {
                    shouldInclude = true
                }
            }
            
            // Overdue filter
            if template.includeOverdue && reminder.isOverdue {
                shouldInclude = true
            }
            
            // Tag filter
            if !template.includeSpecificTags.isEmpty {
                let reminderTags = reminder.tagNames
                if template.includeSpecificTags.contains(where: { reminderTags.contains($0) }) {
                    shouldInclude = true
                }
            }
            
            // List filter (would need list relationship)
            // This would require additional implementation
            
            if shouldInclude {
                selectedReminders.append(reminder)
            }
        }
        
        // Limit results
        if selectedReminders.count > template.maxReminders {
            selectedReminders = Array(selectedReminders.prefix(template.maxReminders))
        }
        
        return selectedReminders
    }
    
    func completeReminderInSession(_ reminder: Reminder, context: ModelContext) {
        guard let session = currentSession else { return }
        
        reminder.isCompleted = true
        reminder.completedAt = Date()
        
        session.tasksCompleted += 1
        session.completedReminders?.append(reminder)
        
        do {
            try context.save()
            logger.info("Completed reminder in focus session: \(reminder.title)")
        } catch {
            logger.error("Failed to complete reminder: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Template Management
    
    func createTemplate(
        name: String,
        focusType: FocusType,
        duration: TimeInterval,
        context: ModelContext
    ) -> FocusTemplate {
        let template = FocusTemplate(name: name, focusType: focusType, duration: duration)
        context.insert(template)
        
        do {
            try context.save()
            logger.info("Created focus template: \(name)")
        } catch {
            logger.error("Failed to create template: \(error.localizedDescription)")
        }
        
        return template
    }
    
    func getTemplates(context: ModelContext) -> [FocusTemplate] {
        let descriptor = FetchDescriptor<FocusTemplate>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.name)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func getPopularTemplates(context: ModelContext, limit: Int = 5) -> [FocusTemplate] {
        let descriptor = FetchDescriptor<FocusTemplate>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.usageCount, order: .reverse)]
        )
        
        let templates = (try? context.fetch(descriptor)) ?? []
        return Array(templates.prefix(limit))
    }
    
    // MARK: - Statistics
    
    func getFocusStatistics(context: ModelContext, days: Int = 30) -> FocusStatistics {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.startTime >= startDate && session.startTime <= endDate
            }
        )
        
        let sessions = (try? context.fetch(descriptor)) ?? []
        
        let totalSessions = sessions.count
        let totalFocusTime = sessions.reduce(0) { $0 + $1.actualDuration }
        let averageSessionLength = totalSessions > 0 ? totalFocusTime / Double(totalSessions) : 0
        let completedSessions = sessions.filter { $0.wasCompleted }.count
        let completionRate = totalSessions > 0 ? Double(completedSessions) / Double(totalSessions) : 0
        let averageProductivityScore = sessions.isEmpty ? 0 : sessions.reduce(0) { $0 + $1.productivityScore } / Double(sessions.count)
        let totalInterruptions = sessions.reduce(0) { $0 + $1.interruptionCount }
        let totalBreakTime = sessions.flatMap { $0.breaks ?? [] }.reduce(0) { $0 + $1.actualDuration }
        
        // Calculate most productive time of day
        let mostProductiveHour = calculateMostProductiveHour(sessions: sessions)
        
        // Calculate most productive focus type
        let mostProductiveFocusType = calculateMostProductiveFocusType(sessions: sessions)
        
        // Calculate streak
        let streakDays = calculateFocusStreak(sessions: sessions)
        
        return FocusStatistics(
            totalSessions: totalSessions,
            totalFocusTime: totalFocusTime,
            averageSessionLength: averageSessionLength,
            completionRate: completionRate,
            averageProductivityScore: averageProductivityScore,
            totalInterruptions: totalInterruptions,
            mostProductiveTimeOfDay: mostProductiveHour,
            mostProductiveFocusType: mostProductiveFocusType,
            streakDays: streakDays,
            totalBreakTime: totalBreakTime
        )
    }
    
    private func calculateMostProductiveHour(sessions: [FocusSession]) -> Int {
        var hourlyProductivity: [Int: Double] = [:]
        
        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            hourlyProductivity[hour, default: 0] += session.productivityScore
        }
        
        return hourlyProductivity.max(by: { $0.value < $1.value })?.key ?? 9
    }
    
    private func calculateMostProductiveFocusType(sessions: [FocusSession]) -> FocusType {
        var typeProductivity: [FocusType: Double] = [:]
        
        for session in sessions {
            typeProductivity[session.focusType, default: 0] += session.productivityScore
        }
        
        return typeProductivity.max(by: { $0.value < $1.value })?.key ?? .work
    }
    
    private func calculateFocusStreak(sessions: [FocusSession]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        let sessionsByDate = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startTime)
        }
        
        while let sessionsForDate = sessionsByDate[currentDate], !sessionsForDate.isEmpty {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        return streak
    }
    
    private func updateDailyStatistics(session: FocusSession, context: ModelContext) {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(session.startTime) {
            todaysFocusTime += session.actualDuration
            todaysSessionCount += 1
        }
        
        // Update goals
        updateFocusGoals(session: session, context: context)
    }
    
    // MARK: - Goals Management
    
    func createGoal(title: String, type: FocusGoalType, target: Double, context: ModelContext) -> FocusGoal {
        let goal = FocusGoal(title: title, targetType: type, targetValue: target)
        context.insert(goal)
        
        do {
            try context.save()
            logger.info("Created focus goal: \(title)")
        } catch {
            logger.error("Failed to create goal: \(error.localizedDescription)")
        }
        
        return goal
    }
    
    private func updateFocusGoals(session: FocusSession, context: ModelContext) {
        let descriptor = FetchDescriptor<FocusGoal>(
            predicate: #Predicate { $0.isActive && !$0.isCompleted }
        )
        
        let goals = (try? context.fetch(descriptor)) ?? []
        
        for goal in goals {
            switch goal.targetType {
            case .dailyTime:
                if Calendar.current.isDateInToday(session.startTime) {
                    goal.updateProgress(value: todaysFocusTime / 3600) // Convert to hours
                }
            case .dailySessions:
                if Calendar.current.isDateInToday(session.startTime) {
                    goal.updateProgress(value: Double(todaysSessionCount))
                }
            case .productivityScore:
                goal.updateProgress(value: session.productivityScore)
            // Add other goal types as needed
            default:
                break
            }
        }
        
        do {
            try context.save()
        } catch {
            logger.error("Failed to update goals: \(error.localizedDescription)")
        }
    }
    
    // MARK: - System Integration
    
    private func configureSystemFocusMode(for session: FocusSession) {
        // This would integrate with iOS Focus modes
        // Implementation would depend on available APIs
        logger.info("Configuring system focus mode for session type: \(session.focusType.displayName)")
    }
    
    private func clearSystemFocusMode() {
        // Clear system focus mode configuration
        logger.info("Clearing system focus mode")
    }
    
    // MARK: - Notifications
    
    private func setupNotificationHandling() {
        // Set up notification handling for focus sessions
    }
    
    private func scheduleSessionNotifications(for session: FocusSession) {
        let center = UNUserNotificationCenter.current()
        
        // Schedule completion notification
        let completionContent = UNMutableNotificationContent()
        completionContent.title = "Focus Session Complete"
        completionContent.body = "Great job! You've completed your \(session.name) session."
        completionContent.sound = .default
        
        let completionTrigger = UNTimeIntervalNotificationTrigger(
            timeInterval: session.plannedDuration,
            repeats: false
        )
        
        let completionRequest = UNNotificationRequest(
            identifier: "focus_session_complete_\(session.id)",
            content: completionContent,
            trigger: completionTrigger
        )
        
        center.add(completionRequest) { error in
            if let error = error {
                self.logger.error("Failed to schedule completion notification: \(error.localizedDescription)")
            }
        }
        
        // Schedule halfway notification
        if session.plannedDuration > 600 { // Only for sessions longer than 10 minutes
            let halfwayContent = UNMutableNotificationContent()
            halfwayContent.title = "Focus Session Halfway"
            halfwayContent.body = "You're halfway through your focus session. Keep going!"
            halfwayContent.sound = .default
            
            let halfwayTrigger = UNTimeIntervalNotificationTrigger(
                timeInterval: session.plannedDuration / 2,
                repeats: false
            )
            
            let halfwayRequest = UNNotificationRequest(
                identifier: "focus_session_halfway_\(session.id)",
                content: halfwayContent,
                trigger: halfwayTrigger
            )
            
            center.add(halfwayRequest) { error in
                if let error = error {
                    self.logger.error("Failed to schedule halfway notification: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func cancelSessionNotifications() {
        guard let session = currentSession else { return }
        
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            "focus_session_complete_\(session.id)",
            "focus_session_halfway_\(session.id)"
        ])
    }
    
    private func sendSessionCompletionNotification() {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Focus Session Complete!"
        content.body = "Congratulations! You've completed your focus session."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                self.logger.error("Failed to send completion notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendBreakCompletionNotification() {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Break Time Over"
        content.body = "Time to get back to your focus session!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                self.logger.error("Failed to send break notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func suggestBreak() {
        // This could show an in-app suggestion for taking a break
        logger.info("Suggesting break to user")
    }
}
