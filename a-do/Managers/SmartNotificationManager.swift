//
//  SmartNotificationManager.swift
//  a-do
//
//  Smart notification system manager
//

import Foundation
import SwiftData
import UserNotifications
import Observation
import os
import CoreLocation

@MainActor
@Observable
final class SmartNotificationManager: NSObject {
    static let shared = SmartNotificationManager()
    
    private let logger = Logger(subsystem: "a-do", category: "SmartNotifications")
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // Processing state
    var isProcessing: Bool = false
    var lastProcessingDate: Date?
    var pendingNotifications: [SmartNotification] = []
    var deliveryQueue: [SmartNotification] = []
    
    // Configuration
    private var configuration: SmartNotificationConfiguration?
    
    // Analytics
    private var patterns: [NotificationPattern] = []
    private var analytics: [NotificationAnalytics] = []
    
    // Timers
    nonisolated(unsafe) private var processingTimer: Timer?
    nonisolated(unsafe) private var analyticsTimer: Timer?
    
    override init() {
        super.init()
        setupNotificationCenter()
        setupPeriodicProcessing()
    }
    
    nonisolated deinit {
        processingTimer?.invalidate()
        analyticsTimer?.invalidate()
    }
    
    // MARK: - Configuration Management
    
    func getConfiguration(userId: String, context: ModelContext) -> SmartNotificationConfiguration {
        if let config = configuration, config.userId == userId {
            return config
        }
        
        let descriptor = FetchDescriptor<SmartNotificationConfiguration>(
            predicate: #Predicate { $0.userId == userId }
        )
        
        if let existingConfig = try? context.fetch(descriptor).first {
            configuration = existingConfig
            return existingConfig
        }
        
        // Create default configuration
        let newConfig = SmartNotificationConfiguration(userId: userId)
        context.insert(newConfig)
        
        do {
            try context.save()
            configuration = newConfig
            logger.info("Created smart notification configuration for user: \(userId)")
        } catch {
            logger.error("Failed to create notification configuration: \(error.localizedDescription)")
        }
        
        return newConfig
    }
    
    // MARK: - Notification Center Setup
    
    private func setupNotificationCenter() {
        notificationCenter.delegate = self
        
        // Define notification categories with actions
        let categories = createNotificationCategories()
        notificationCenter.setNotificationCategories(categories)
    }
    
    private func createNotificationCategories() -> Set<UNNotificationCategory> {
        var categories: Set<UNNotificationCategory> = []
        
        // Reminder category
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "Complete",
            options: [.foreground]
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze",
            options: []
        )
        let reminderCategory = UNNotificationCategory(
            identifier: "REMINDER_CATEGORY",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        categories.insert(reminderCategory)
        
        // Habit reminder category
        let logHabitAction = UNNotificationAction(
            identifier: "LOG_HABIT_ACTION",
            title: "Log Habit",
            options: [.foreground]
        )
        let skipHabitAction = UNNotificationAction(
            identifier: "SKIP_HABIT_ACTION",
            title: "Skip Today",
            options: []
        )
        let habitCategory = UNNotificationCategory(
            identifier: "HABIT_CATEGORY",
            actions: [logHabitAction, skipHabitAction],
            intentIdentifiers: [],
            options: []
        )
        categories.insert(habitCategory)
        
        // Focus session category
        let startFocusAction = UNNotificationAction(
            identifier: "START_FOCUS_ACTION",
            title: "Start Session",
            options: [.foreground]
        )
        let postponeFocusAction = UNNotificationAction(
            identifier: "POSTPONE_FOCUS_ACTION",
            title: "Postpone",
            options: []
        )
        let focusCategory = UNNotificationCategory(
            identifier: "FOCUS_CATEGORY",
            actions: [startFocusAction, postponeFocusAction],
            intentIdentifiers: [],
            options: []
        )
        categories.insert(focusCategory)
        
        return categories
    }
    
    // MARK: - Smart Notification Scheduling
    
    func scheduleSmartNotification(
        userId: String,
        type: SmartNotificationType,
        title: String,
        body: String,
        scheduledDate: Date,
        priority: NotificationPriorityLevel = .medium,
        context: NotificationContext = .general,
        relatedReminder: Reminder? = nil,
        relatedHabit: Habit? = nil,
        modelContext: ModelContext
    ) async {
        let config = getConfiguration(userId: userId, context: modelContext)
        
        guard config.isEnabled else {
            logger.info("Smart notifications disabled for user: \(userId)")
            return
        }
        
        let smartNotification = SmartNotification(
            userId: userId,
            type: type,
            title: title,
            body: body,
            scheduledDate: scheduledDate,
            priority: priority
        )
        
        smartNotification.context = context
        smartNotification.reminder = relatedReminder
        smartNotification.habit = relatedHabit
        
        // Apply smart scheduling logic
        await applySmartScheduling(notification: smartNotification, config: config, context: modelContext)
        
        modelContext.insert(smartNotification)
        
        do {
            try modelContext.save()
            logger.info("Scheduled smart notification: \(title)")
            
            // Add to processing queue
            pendingNotifications.append(smartNotification)
            
        } catch {
            logger.error("Failed to schedule smart notification: \(error.localizedDescription)")
        }
    }
    
    private func applySmartScheduling(
        notification: SmartNotification,
        config: SmartNotificationConfiguration,
        context: ModelContext
    ) async {
        // Apply adaptive timing if enabled
        if config.adaptiveTimingEnabled {
            await applyAdaptiveTiming(notification: notification, userId: config.userId, context: context)
        }
        
        // Apply context-aware scheduling
        if config.contextAwareEnabled {
            await applyContextAwareScheduling(notification: notification, config: config)
        }
        
        // Check for quiet hours
        if config.isInQuietHours {
            await handleQuietHours(notification: notification, config: config)
        }
        
        // Apply intelligent grouping
        if config.intelligentGroupingEnabled {
            await applyIntelligentGrouping(notification: notification, config: config, context: context)
        }
        
        // Calculate adaptive score
        notification.adaptiveScore = await calculateAdaptiveScore(notification: notification, context: context)
    }
    
    private func applyAdaptiveTiming(notification: SmartNotification, userId: String, context: ModelContext) async {
        // Find optimal time based on user patterns
        let optimalTime = await findOptimalDeliveryTime(
            for: notification.type,
            context: notification.context,
            userId: userId,
            modelContext: context
        )
        
        if let optimalTime = optimalTime {
            let calendar = Calendar.current
            let originalComponents = calendar.dateComponents([.year, .month, .day], from: notification.scheduledDate)
            let optimalComponents = calendar.dateComponents([.hour, .minute], from: optimalTime)
            
            var newComponents = originalComponents
            newComponents.hour = optimalComponents.hour
            newComponents.minute = optimalComponents.minute
            
            if let newDate = calendar.date(from: newComponents) {
                notification.scheduledDate = newDate
                notification.timeContext = "Optimized for \(optimalTime.formatted(date: .omitted, time: .shortened))"
            }
        }
    }
    
    private func applyContextAwareScheduling(notification: SmartNotification, config: SmartNotificationConfiguration) async {
        // Apply location-based adjustments
        if config.locationBasedEnabled {
            await applyLocationContext(notification: notification)
        }
        
        // Apply activity-based adjustments
        if config.activityBasedEnabled {
            await applyActivityContext(notification: notification)
        }
        
        // Apply device state context
        await applyDeviceContext(notification: notification)
    }
    
    private func handleQuietHours(notification: SmartNotification, config: SmartNotificationConfiguration) async {
        // If notification is scheduled during quiet hours, reschedule to end of quiet hours
        if config.isInQuietHours {
            let calendar = Calendar.current
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
            let quietEnd = calendar.date(
                bySettingHour: calendar.component(.hour, from: config.quietHoursEnd),
                minute: calendar.component(.minute, from: config.quietHoursEnd),
                second: 0,
                of: tomorrow
            ) ?? tomorrow
            
            notification.reschedule(newDate: quietEnd)
            notification.timeContext = "Rescheduled due to quiet hours"
        }
    }
    
    private func applyIntelligentGrouping(
        notification: SmartNotification,
        config: SmartNotificationConfiguration,
        context: ModelContext
    ) async {
        guard config.batchSimilarNotifications else { return }
        
        // Find similar notifications scheduled around the same time
        let timeWindow: TimeInterval = 1800 // 30 minutes
        let startTime = notification.scheduledDate.addingTimeInterval(-timeWindow)
        let endTime = notification.scheduledDate.addingTimeInterval(timeWindow)
        
        let userId = notification.userId
        let scheduledStatusRaw = NotificationStatus.scheduled.rawValue
        let notifTypeRaw = notification.type.rawValue
        
        let descriptor = FetchDescriptor<SmartNotification>(
            predicate: #Predicate<SmartNotification> { n in
                n.userId == userId &&
                n.statusRaw == scheduledStatusRaw &&
                n.scheduledDate >= startTime &&
                n.scheduledDate <= endTime &&
                n.typeRaw == notifTypeRaw
            }
        )
        
        let similarNotifications = (try? context.fetch(descriptor)) ?? []
        
        if similarNotifications.count >= 2 {
            // Create or find existing batch
            let batchId = await createOrFindBatch(
                for: similarNotifications,
                type: .similar,
                userId: notification.userId,
                context: context
            )
            
            notification.batchId = batchId
        }
    }
    
    // MARK: - Notification Processing
    
    private func setupPeriodicProcessing() {
        // Process notifications every minute
        processingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.processNotificationQueue()
            }
        }
        
        // Update analytics every hour
        analyticsTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateAnalytics()
            }
        }
    }
    
    private func processNotificationQueue() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let now = Date()
        let dueNotifications = pendingNotifications.filter { notification in
            notification.scheduledDate <= now && notification.status == .scheduled
        }
        
        for notification in dueNotifications {
            await deliverNotification(notification)
        }
        
        // Remove processed notifications from pending queue
        pendingNotifications.removeAll { notification in
            notification.status != .scheduled
        }
        
        lastProcessingDate = now
    }
    
    private func deliverNotification(_ notification: SmartNotification) async {
        do {
            // Create UNNotificationRequest
            let content = createNotificationContent(for: notification)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: notification.id.uuidString,
                content: content,
                trigger: trigger
            )
            
            // Schedule with system
            try await notificationCenter.add(request)
            
            // Mark as delivered
            notification.markAsDelivered()
            
            logger.info("Delivered notification: \(notification.title)")
            
        } catch {
            notification.status = .failed
            logger.error("Failed to deliver notification: \(error.localizedDescription)")
            
            // Retry if possible
            if notification.shouldRetry {
                let retryDelay: TimeInterval = 300 // 5 minutes
                notification.reschedule(newDate: Date().addingTimeInterval(retryDelay))
            }
        }
    }
    
    private func createNotificationContent(for notification: SmartNotification) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        
        // Set category based on type
        switch notification.type {
        case .reminder:
            content.categoryIdentifier = "REMINDER_CATEGORY"
        case .habitReminder:
            content.categoryIdentifier = "HABIT_CATEGORY"
        case .focusStart, .focusBreak:
            content.categoryIdentifier = "FOCUS_CATEGORY"
        default:
            break
        }
        
        // Set sound based on priority
        switch notification.priority {
        case .low:
            content.sound = .default
        case .medium:
            content.sound = .default
        case .high:
            content.sound = UNNotificationSound(named: UNNotificationSoundName("high_priority.wav"))
        case .critical:
            content.sound = .defaultCritical
        }
        
        // Add user info for handling
        content.userInfo = [
            "notificationId": notification.id.uuidString,
            "type": notification.type.rawValue,
            "priority": notification.priority.rawValue,
            "reminderId": notification.reminder?.uuid.uuidString ?? "",
            "habitId": notification.habit?.id.uuidString ?? ""
        ]
        
        return content
    }
    
    // MARK: - Pattern Learning
    
    private func findOptimalDeliveryTime(
        for type: SmartNotificationType,
        context: NotificationContext,
        userId: String,
        modelContext: ModelContext
    ) async -> Date? {
        let timeOfDayTypeRaw = NotificationPatternType.timeOfDay.rawValue
        let descriptor = FetchDescriptor<NotificationPattern>(
            predicate: #Predicate<NotificationPattern> { pattern in
                pattern.userId == userId &&
                pattern.patternTypeRaw == timeOfDayTypeRaw &&
                pattern.isActive &&
                pattern.confidence > 0.5
            },
            sortBy: [SortDescriptor(\.engagementRate, order: .reverse)]
        )
        
        let patterns = (try? modelContext.fetch(descriptor)) ?? []
        
        // Find the best time pattern
        if let bestPattern = patterns.first {
            // Parse time from context value (e.g., "09:30")
            let components = bestPattern.contextValue.split(separator: ":")
            if components.count == 2,
               let hour = Int(components[0]),
               let minute = Int(components[1]) {
                
                let calendar = Calendar.current
                return calendar.date(from: DateComponents(hour: hour, minute: minute))
            }
        }
        
        return nil
    }
    
    private func applyLocationContext(notification: SmartNotification) async {
        // This would integrate with Core Location to determine current location context
        // For now, we'll use a placeholder
        notification.locationContext = "Home" // This would be determined by actual location
    }
    
    private func applyActivityContext(notification: SmartNotification) async {
        // This would integrate with motion sensors or HealthKit to determine activity
        // For now, use time-based context
        let hour = Calendar.current.component(.hour, from: Date())
        let activityContext: String
        
        switch hour {
        case 6..<9:
            activityContext = "Starting"
        case 9..<12:
            activityContext = "Focused"
        case 12..<14:
            activityContext = "Break"
        case 14..<17:
            activityContext = "Active"
        case 17..<19:
            activityContext = "Winding Down"
        default:
            activityContext = "Relaxed"
        }
        
        notification.activityContext = activityContext
    }
    
    private func applyDeviceContext(notification: SmartNotification) async {
        // Determine device state (charging, battery level, do not disturb, etc.)
        // For now, assume active state
        notification.deviceContext = "Active"
    }
    
    private func calculateAdaptiveScore(notification: SmartNotification, context: ModelContext) async -> Double {
        var score = 0.5 // Base score
        
        // Factor in priority
        score += Double(notification.priority.urgencyScore) * 0.2
        
        // Factor in historical engagement for this type and context
        let engagementRate = await getHistoricalEngagementRate(
            type: notification.type,
            context: notification.context,
            userId: notification.userId,
            modelContext: context
        )
        score += engagementRate * 0.3
        
        // Factor in timing optimality
        if notification.timeContext?.contains("Optimized") == true {
            score += 0.2
        }
        
        return min(1.0, max(0.0, score))
    }
    
    private func getHistoricalEngagementRate(
        type: SmartNotificationType,
        context: NotificationContext,
        userId: String,
        modelContext: ModelContext
    ) async -> Double {
        let deliveredStatusRaw = NotificationStatus.delivered.rawValue
        let typeRaw = type.rawValue
        let contextRaw = context.rawValue
        let descriptor = FetchDescriptor<SmartNotification>(
            predicate: #Predicate<SmartNotification> { n in
                n.userId == userId &&
                n.typeRaw == typeRaw &&
                n.contextRaw == contextRaw &&
                n.statusRaw == deliveredStatusRaw
            }
        )
        
        let historicalNotifications = (try? modelContext.fetch(descriptor)) ?? []
        
        guard !historicalNotifications.isEmpty else { return 0.5 }
        
        let engagedCount = historicalNotifications.filter { $0.userEngagement != .none }.count
        return Double(engagedCount) / Double(historicalNotifications.count)
    }
    
    private func createOrFindBatch(
        for notifications: [SmartNotification],
        type: NotificationBatchType,
        userId: String,
        context: ModelContext
    ) async -> String {
        // Check if there's an existing batch for these notifications
        let scheduledStatusRaw = NotificationStatus.scheduled.rawValue
        let batchTypeRaw = type.rawValue
        let batchDescriptor = FetchDescriptor<NotificationBatch>(
            predicate: #Predicate<NotificationBatch> { batch in
                batch.userId == userId &&
                batch.batchTypeRaw == batchTypeRaw &&
                batch.statusRaw == scheduledStatusRaw
            }
        )
        
        if let existingBatch = try? context.fetch(batchDescriptor).first {
            return existingBatch.id.uuidString
        }
        
        // Create new batch
        let batch = NotificationBatch(
            userId: userId,
            batchType: type,
            title: "Grouped Notifications"
        )
        
        context.insert(batch)
        
        do {
            try context.save()
            return batch.id.uuidString
        } catch {
            logger.error("Failed to create notification batch: \(error.localizedDescription)")
            return UUID().uuidString
        }
    }
    
    // MARK: - Analytics
    
    private func updateAnalytics() async {
        // This would update notification analytics
        logger.info("Updating notification analytics")
    }
    
    func recordNotificationEngagement(
        notificationId: UUID,
        engagement: NotificationEngagement,
        responseTime: TimeInterval,
        context: ModelContext
    ) {
        let descriptor = FetchDescriptor<SmartNotification>(
            predicate: #Predicate { $0.id == notificationId }
        )
        
        guard let notification = try? context.fetch(descriptor).first else { return }
        
        notification.markAsEngaged(engagement: engagement)
        
        // Update patterns
        updateNotificationPatterns(
            notification: notification,
            engagement: engagement,
            responseTime: responseTime,
            context: context
        )
        
        do {
            try context.save()
            logger.info("Recorded notification engagement: \(engagement.displayName)")
        } catch {
            logger.error("Failed to record notification engagement: \(error.localizedDescription)")
        }
    }
    
    private func updateNotificationPatterns(
        notification: SmartNotification,
        engagement: NotificationEngagement,
        responseTime: TimeInterval,
        context: ModelContext
    ) {
        // Update time-of-day pattern
        if let deliveryDate = notification.actualDeliveryDate {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let timeString = timeFormatter.string(from: deliveryDate)
            
            updatePattern(
                userId: notification.userId,
                type: .timeOfDay,
                contextValue: timeString,
                engagement: engagement,
                responseTime: responseTime,
                context: context
            )
        }
        
        // Update day-of-week pattern
        if let deliveryDate = notification.actualDeliveryDate {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            let dayString = dayFormatter.string(from: deliveryDate)
            
            updatePattern(
                userId: notification.userId,
                type: .dayOfWeek,
                contextValue: dayString,
                engagement: engagement,
                responseTime: responseTime,
                context: context
            )
        }
        
        // Update other patterns based on context
        if let locationContext = notification.locationContext {
            updatePattern(
                userId: notification.userId,
                type: .location,
                contextValue: locationContext,
                engagement: engagement,
                responseTime: responseTime,
                context: context
            )
        }
    }
    
    private func updatePattern(
        userId: String,
        type: NotificationPatternType,
        contextValue: String,
        engagement: NotificationEngagement,
        responseTime: TimeInterval,
        context: ModelContext
    ) {
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<NotificationPattern>(
            predicate: #Predicate<NotificationPattern> { pattern in
                pattern.userId == userId &&
                pattern.patternTypeRaw == typeRaw &&
                pattern.contextValue == contextValue
            }
        )
        
        let existingPattern = try? context.fetch(descriptor).first
        
        if let pattern = existingPattern {
            pattern.updateMetrics(engagement: engagement, responseTime: responseTime)
        } else {
            let newPattern = NotificationPattern(
                userId: userId,
                patternType: type,
                contextValue: contextValue
            )
            newPattern.updateMetrics(engagement: engagement, responseTime: responseTime)
            context.insert(newPattern)
        }
    }
    
    // MARK: - Notification Management
    
    func cancelNotification(_ notificationId: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<SmartNotification>(
            predicate: #Predicate { $0.id == notificationId }
        )
        
        guard let notification = try? context.fetch(descriptor).first else { return }
        
        // Cancel system notification
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationId.uuidString])
        
        // Update status
        notification.cancel()
        
        do {
            try context.save()
            logger.info("Cancelled notification: \(notification.title)")
        } catch {
            logger.error("Failed to cancel notification: \(error.localizedDescription)")
        }
    }
    
    func snoozeNotification(_ notificationId: UUID, snoozeTime: TimeInterval, context: ModelContext) {
        let descriptor = FetchDescriptor<SmartNotification>(
            predicate: #Predicate { $0.id == notificationId }
        )
        
        guard let notification = try? context.fetch(descriptor).first else { return }
        
        let newDate = Date().addingTimeInterval(snoozeTime)
        notification.reschedule(newDate: newDate)
        notification.markAsEngaged(engagement: .snoozed)
        
        do {
            try context.save()
            logger.info("Snoozed notification: \(notification.title)")
            
            // Re-add to pending queue
            pendingNotifications.append(notification)
            
        } catch {
            logger.error("Failed to snooze notification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Bulk Operations
    
    func suppressNotificationsForContext(_ context: NotificationContext, duration: TimeInterval, userId: String, modelContext: ModelContext) {
        let endTime = Date().addingTimeInterval(duration)
        
        let scheduledStatusRaw = NotificationStatus.scheduled.rawValue
        let contextRaw = context.rawValue
        let descriptor = FetchDescriptor<SmartNotification>(
            predicate: #Predicate<SmartNotification> { n in
                n.userId == userId &&
                n.contextRaw == contextRaw &&
                n.statusRaw == scheduledStatusRaw &&
                n.scheduledDate <= endTime
            }
        )
        
        let notifications = (try? modelContext.fetch(descriptor)) ?? []
        
        for notification in notifications {
            notification.status = .suppressed
        }
        
        do {
            try modelContext.save()
            logger.info("Suppressed \(notifications.count) notifications for context: \(context.displayName)")
        } catch {
            logger.error("Failed to suppress notifications: \(error.localizedDescription)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension SmartNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        guard let notificationIdString = userInfo["notificationId"] as? String,
              let notificationId = UUID(uuidString: notificationIdString) else {
            completionHandler()
            return
        }
        
        let engagement: NotificationEngagement
        let responseTime = Date().timeIntervalSince(response.notification.date)
        
        switch response.actionIdentifier {
        case "COMPLETE_ACTION":
            engagement = .actionTaken
            // Handle completion logic
        case "SNOOZE_ACTION":
            engagement = .snoozed
            // Handle snooze logic
        case "LOG_HABIT_ACTION":
            engagement = .actionTaken
            // Handle habit logging
        case "SKIP_HABIT_ACTION":
            engagement = .actionTaken
            // Handle habit skipping
        case "START_FOCUS_ACTION":
            engagement = .actionTaken
            // Handle focus session start
        case UNNotificationDefaultActionIdentifier:
            engagement = .tapped
        case UNNotificationDismissActionIdentifier:
            engagement = .dismissed
        default:
            engagement = .viewed
        }
        
        // Record engagement (this would need access to model context)
        logger.info("Notification engagement: \(engagement.displayName) for \(notificationId)")
        
        completionHandler()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}

