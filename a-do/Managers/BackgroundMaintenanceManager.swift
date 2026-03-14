import Foundation
import SwiftData
import os
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

final class BackgroundMaintenanceManager {
    static let shared = BackgroundMaintenanceManager()

    private let logger = Logger(subsystem: "a-do", category: "BackgroundMaintenance")
    private let refreshIdentifier = "JAMSoft.a-do.refresh"
    private let processingIdentifier = "JAMSoft.a-do.processing"

    private init() {}

    func registerTasks() {
        guard !RuntimeEnvironment.isRunningTests else { return }
        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleRefreshTask(refreshTask)
        }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingIdentifier, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleProcessingTask(processingTask)
        }
        #endif
    }

    func scheduleAll(reason: String) {
        guard !RuntimeEnvironment.isRunningTests else { return }
        scheduleRefresh(reason: reason)
        scheduleProcessing(reason: reason)
    }

    func scheduleRefresh(reason: String) {
        guard !RuntimeEnvironment.isRunningTests else { return }
        #if canImport(BackgroundTasks)
        let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        submit(request: request, description: "refresh", reason: reason)
        #endif
    }

    func scheduleProcessing(reason: String) {
        guard !RuntimeEnvironment.isRunningTests else { return }
        #if canImport(BackgroundTasks)
        let request = BGProcessingTaskRequest(identifier: processingIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60 * 60)
        submit(request: request, description: "processing", reason: reason)
        #endif
    }

    private func submit(request: BGTaskRequest, description: String, reason: String) {
        #if canImport(BackgroundTasks)
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled \(description, privacy: .public) background task for \(reason, privacy: .public)")
        } catch {
            logger.error("Failed to schedule \(description, privacy: .public) background task for \(reason, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    private func handleRefreshTask(_ task: BGAppRefreshTask) {
        scheduleRefresh(reason: "refreshExecution")

        let work = Task(priority: .background) {
            await self.runRefreshMaintenance(reason: "bgRefresh")
        }

        task.expirationHandler = {
            work.cancel()
        }

        Task {
            let success = await work.value
            task.setTaskCompleted(success: success)
        }
    }

    private func handleProcessingTask(_ task: BGProcessingTask) {
        scheduleProcessing(reason: "processingExecution")

        let work = Task(priority: .background) {
            await self.runProcessingMaintenance(reason: "bgProcessing")
        }

        task.expirationHandler = {
            work.cancel()
        }

        Task {
            let success = await work.value
            task.setTaskCompleted(success: success)
        }
    }

    private func runRefreshMaintenance(reason: String) async -> Bool {
        guard !Task.isCancelled else { return false }

        let container = AppContainer.shared.getContainer()
        let context = ModelContext(container)
        let userId = SecurityUtils.getCurrentUserID()

        await AppleRemindersSyncManager.shared.performLifecycleSyncIfNeeded(context: context, reason: reason)
        await AdvancedSearchManager.shared.refreshIndexIfNeeded(context: context, reason: reason)
        await SmartNotificationManager.shared.performMaintenanceIfNeeded(context: context, reason: reason)
        await AIManager.shared.refreshIfNeeded(userId: userId, context: context, reason: reason)

        return !Task.isCancelled
    }

    private func runProcessingMaintenance(reason: String) async -> Bool {
        guard !Task.isCancelled else { return false }

        let container = AppContainer.shared.getContainer()
        let context = ModelContext(container)

        await RecurringRemindersManager.shared.processRecurringRemindersIfNeeded(context: context, reason: reason, force: true)
        await BackupManager.shared.checkScheduledBackupsIfNeeded(context: context, reason: reason, force: true)
        await BehavioralLearningManager.shared.flushIfNeeded(context: context, reason: reason, force: true)
        await AIBehavioralIntegrationCoordinator.shared.runLearningCycleIfNeeded(context: context, reason: reason, force: true)
        await GamificationManager.shared.refreshIfNeeded(context: context, reason: reason, force: true)

        return !Task.isCancelled
    }
}
