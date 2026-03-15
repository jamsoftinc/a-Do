//
//  HealthKitManager.swift
//  a-do
//
//  HealthKit integration manager
//

import Foundation
import SwiftData
import HealthKit
import Observation
import os

@MainActor
@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()
    
    private let logger = Logger(subsystem: "a-do", category: "HealthKit")
    private let healthStore = HKHealthStore()
    
    // Authorization state
    var isHealthKitAvailable: Bool = false
    var hasPermission: Bool = false
    var authorizationStatus: HKAuthorizationStatus = .notDetermined
    
    // Sync state
    var isSyncing: Bool = false
    var lastSyncDate: Date?
    var syncError: String?
    
    // Configuration
    private var configuration: HealthIntegrationConfiguration?
    
    // Background delivery
    private var backgroundDeliveryTokens: [HKObjectType: Any] = [:]
    
    private init() {
        isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
        setupBackgroundDelivery()
    }
    
    // MARK: - Configuration Management
    
    func getConfiguration(userId: String, context: ModelContext) -> HealthIntegrationConfiguration {
        if let config = configuration, config.userId == userId {
            return config
        }
        
        let descriptor = FetchDescriptor<HealthIntegrationConfiguration>(
            predicate: #Predicate { $0.userId == userId }
        )
        
        if let existingConfig = try? context.fetch(descriptor).first {
            configuration = existingConfig
            return existingConfig
        }
        
        // Create default configuration
        let newConfig = HealthIntegrationConfiguration(userId: userId)
        context.insert(newConfig)
        
        do {
            try context.save()
            configuration = newConfig
            logger.info("Created health integration configuration for user: \(userId)")
        } catch {
            logger.error("Failed to create health configuration: \(error.localizedDescription)")
        }
        
        return newConfig
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        guard isHealthKitAvailable else {
            logger.warning("HealthKit is not available on this device")
            return false
        }
        
        // Build typesToRead set safely without force unwraps
        var typesToRead: Set<HKObjectType> = [HKObjectType.workoutType()]

        // Add quantity types safely
        let quantityIdentifiersToRead: [HKQuantityTypeIdentifier] = [
            .stepCount, .distanceWalkingRunning, .flightsClimbed,
            .activeEnergyBurned, .basalEnergyBurned, .heartRate,
            .bloodPressureSystolic, .bloodPressureDiastolic,
            .bodyMass, .bodyMassIndex, .dietaryWater
        ]
        for identifier in quantityIdentifiersToRead {
            if let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) {
                typesToRead.insert(quantityType)
            }
        }

        // Add category types safely
        let categoryIdentifiersToRead: [HKCategoryTypeIdentifier] = [.sleepAnalysis, .mindfulSession]
        for identifier in categoryIdentifiersToRead {
            if let categoryType = HKObjectType.categoryType(forIdentifier: identifier) {
                typesToRead.insert(categoryType)
            }
        }

        // Build typesToWrite set safely without force unwraps
        var typesToWrite: Set<HKSampleType> = [HKObjectType.workoutType()]

        // Add quantity types for writing safely
        let quantityIdentifiersToWrite: [HKQuantityTypeIdentifier] = [.stepCount, .dietaryWater]
        for identifier in quantityIdentifiersToWrite {
            if let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) {
                typesToWrite.insert(quantityType)
            }
        }

        // Add category types for writing safely
        if let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            typesToWrite.insert(mindfulType)
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)

            // Check authorization status for key types
            guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
                logger.error("Failed to get steps quantity type for authorization check")
                return false
            }
            let stepsAuth = healthStore.authorizationStatus(for: stepsType)
            hasPermission = stepsAuth == .sharingAuthorized || stepsAuth == .sharingDenied
            authorizationStatus = stepsAuth
            
            logger.info("HealthKit authorization completed. Status: \(stepsAuth.rawValue)")
            return hasPermission
            
        } catch {
            logger.error("HealthKit authorization failed: \(error.localizedDescription)")
            syncError = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Data Syncing
    
    func syncHealthData(userId: String, context: ModelContext) async {
        guard hasPermission else {
            logger.warning("No HealthKit permission for syncing")
            return
        }
        
        guard !isSyncing else {
            logger.info("Health sync already in progress")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let config = getConfiguration(userId: userId, context: context)
        
        logger.info("Starting health data sync for user: \(userId)")
        
        do {
            // Sync different data types based on configuration
            if config.syncHabits {
                await syncActivityData(userId: userId, context: context)
            }
            
            if config.syncWorkouts {
                await syncWorkoutData(userId: userId, context: context)
            }
            
            if config.syncSleep {
                await syncSleepData(userId: userId, context: context)
            }
            
            if config.syncMindfulness {
                await syncMindfulnessData(userId: userId, context: context)
            }
            
            if config.syncVitals {
                await syncVitalSigns(userId: userId, context: context)
            }
            
            // Update sync timestamp
            config.lastSyncDate = Date()
            try context.save()
            
            lastSyncDate = Date()
            syncError = nil
            
            logger.info("Health data sync completed successfully")
            
        } catch {
            logger.error("Health data sync failed: \(error.localizedDescription)")
            syncError = error.localizedDescription
        }
    }
    
    // MARK: - Activity Data Sync
    
    private func syncActivityData(userId: String, context: ModelContext) async {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else {
            logger.error("Failed to calculate start date for activity sync")
            return
        }
        
        // Sync steps
        await syncQuantityData(
            type: .stepCount,
            metricType: .steps,
            userId: userId,
            startDate: startDate,
            endDate: endDate,
            context: context
        )
        
        // Sync distance
        await syncQuantityData(
            type: .distanceWalkingRunning,
            metricType: .distance,
            userId: userId,
            startDate: startDate,
            endDate: endDate,
            context: context
        )
        
        // Sync flights climbed
        await syncQuantityData(
            type: .flightsClimbed,
            metricType: .flightsClimbed,
            userId: userId,
            startDate: startDate,
            endDate: endDate,
            context: context
        )
        
        // Sync active energy
        await syncQuantityData(
            type: .activeEnergyBurned,
            metricType: .activeEnergy,
            userId: userId,
            startDate: startDate,
            endDate: endDate,
            context: context
        )
    }
    
    private func syncQuantityData(
        type: HKQuantityTypeIdentifier,
        metricType: HealthMetricType,
        userId: String,
        startDate: Date,
        endDate: Date,
        context: ModelContext
    ) async {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: type) else { return }
        let container = context.container
        let logger = self.logger
        let unit = Self.healthUnit(for: type)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum],
                anchorDate: startDate,
                intervalComponents: DateComponents(day: 1)
            )

            query.initialResultsHandler = { _, results, error in
                defer { continuation.resume(returning: ()) }

                guard let results = results else {
                    if let error = error {
                        logger.error("Failed to fetch \(type.rawValue): \(error.localizedDescription)")
                    }
                    return
                }

                let callbackContext = ModelContext(container)
                results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    guard let sum = statistics.sumQuantity() else { return }

                    let value = sum.doubleValue(for: unit)
                    let date = statistics.startDate

                    // Check if we already have this data
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: date)
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

                    let existingDescriptor = FetchDescriptor<HealthMetric>(
                        predicate: #Predicate<HealthMetric> { metric in
                            metric.userId == userId &&
                            metric.type == metricType &&
                            metric.date >= startOfDay &&
                            metric.date < endOfDay
                        }
                    )

                    if let existing = try? callbackContext.fetch(existingDescriptor).first {
                        existing.value = value
                        existing.syncedAt = Date()
                    } else {
                        let metric = HealthMetric(
                            type: metricType,
                            value: value,
                            unit: metricType.defaultUnit,
                            date: date
                        )
                        metric.userId = userId
                        metric.source = "HealthKit"
                        callbackContext.insert(metric)
                    }
                }

                do {
                    try callbackContext.save()
                } catch {
                    logger.error("Failed to save \(type.rawValue) data: \(error.localizedDescription)")
                }
            }

            healthStore.execute(query)
        }
    }
    
    // MARK: - Workout Data Sync
    
    private func syncWorkoutData(userId: String, context: ModelContext) async {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else {
            logger.error("Failed to calculate start date for workout sync")
            return
        }
        let container = context.container
        let logger = self.logger
        let predicate = HKQuery.predicateForWorkouts(with: .greaterThanOrEqualTo, duration: 60) // At least 1 minute
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, datePredicate])

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: compoundPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                defer { continuation.resume(returning: ()) }

                guard let workouts = samples as? [HKWorkout] else {
                    if let error = error {
                        logger.error("Failed to fetch workouts: \(error.localizedDescription)")
                    }
                    return
                }

                let callbackContext = ModelContext(container)
                for workout in workouts {
                    // Check if we already have this workout
                    let workoutUUID = workout.uuid.uuidString
                    let existingDescriptor = FetchDescriptor<WorkoutIntegration>(
                        predicate: #Predicate<WorkoutIntegration> { w in
                            w.userId == userId && w.healthKitUUID == workoutUUID
                        }
                    )

                    if (try? callbackContext.fetch(existingDescriptor).first) != nil {
                        continue // Already synced
                    }

                    let workoutType = Self.mapWorkoutTypeStatic(workout.workoutActivityType)
                    let workoutIntegration = WorkoutIntegration(
                        workoutType: workoutType,
                        name: workoutType.displayName,
                        startDate: workout.startDate
                    )

                    workoutIntegration.userId = userId
                    workoutIntegration.healthKitUUID = workout.uuid.uuidString

                    let endDate = workout.endDate
                    let calories = Self.activeEnergyKilocalories(for: workout)
                    let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0

                    workoutIntegration.complete(
                        endDate: endDate,
                        calories: calories,
                        distance: distance
                    )

                    callbackContext.insert(workoutIntegration)
                }

                do {
                    try callbackContext.save()
                    logger.info("Synced \(workouts.count) workouts")
                } catch {
                    logger.error("Failed to save workout data: \(error.localizedDescription)")
                }
            }

            healthStore.execute(query)
        }
    }
    
    // MARK: - Sleep Data Sync
    
    private func syncSleepData(userId: String, context: ModelContext) async {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else {
            logger.error("Failed to calculate start date for sleep sync")
            return
        }
        let container = context.container
        let logger = self.logger
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                defer { continuation.resume(returning: ()) }

                guard let sleepSamples = samples as? [HKCategorySample] else {
                    if let error = error {
                        logger.error("Failed to fetch sleep data: \(error.localizedDescription)")
                    }
                    return
                }

                let callbackContext = ModelContext(container)
                // Group sleep samples by date
                var sleepByDate: [Date: [HKCategorySample]] = [:]

                for sample in sleepSamples {
                    let date = calendar.startOfDay(for: sample.startDate)
                    sleepByDate[date, default: []].append(sample)
                }

                for (date, samples) in sleepByDate {
                    // Check if we already have sleep data for this date
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: date)
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

                    let existingDescriptor = FetchDescriptor<SleepIntegration>(
                        predicate: #Predicate<SleepIntegration> { sleep in
                            sleep.userId == userId &&
                            sleep.bedtime >= startOfDay &&
                            sleep.bedtime < endOfDay
                        }
                    )

                    if (try? callbackContext.fetch(existingDescriptor).first) != nil {
                        continue // Already synced
                    }

                    // Calculate sleep metrics from samples
                    let bedtime = samples.map { $0.startDate }.min() ?? date
                    let wakeTime = samples.map { $0.endDate }.max() ?? date

                    let sleepIntegration = SleepIntegration(bedtime: bedtime, wakeTime: wakeTime)
                    sleepIntegration.userId = userId
                    sleepIntegration.source = "HealthKit"

                    callbackContext.insert(sleepIntegration)
                }

                do {
                    try callbackContext.save()
                    logger.info("Synced sleep data for \(sleepByDate.count) days")
                } catch {
                    logger.error("Failed to save sleep data: \(error.localizedDescription)")
                }
            }

            healthStore.execute(query)
        }
    }
    
    // MARK: - Mindfulness Data Sync
    
    private func syncMindfulnessData(userId: String, context: ModelContext) async {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else {
            logger.error("Failed to calculate start date for mindfulness sync")
            return
        }
        let container = context.container
        let logger = self.logger
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(
                sampleType: mindfulType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                defer { continuation.resume(returning: ()) }

                guard let mindfulSamples = samples as? [HKCategorySample] else {
                    if let error = error {
                        logger.error("Failed to fetch mindfulness data: \(error.localizedDescription)")
                    }
                    return
                }

                let callbackContext = ModelContext(container)
                for sample in mindfulSamples {
                    // Check if we already have this session
                    let sampleUUID = sample.uuid.uuidString
                    let existingDescriptor = FetchDescriptor<MindfulnessIntegration>(
                        predicate: #Predicate<MindfulnessIntegration> { session in
                            session.userId == userId && session.healthKitUUID == sampleUUID
                        }
                    )

                    if (try? callbackContext.fetch(existingDescriptor).first) != nil {
                        continue // Already synced
                    }

                    let mindfulnessIntegration = MindfulnessIntegration(
                        sessionType: .meditation,
                        startDate: sample.startDate
                    )

                    mindfulnessIntegration.userId = userId
                    mindfulnessIntegration.healthKitUUID = sample.uuid.uuidString
                    mindfulnessIntegration.complete(endDate: sample.endDate, moodAfter: .good)

                    callbackContext.insert(mindfulnessIntegration)
                }

                do {
                    try callbackContext.save()
                    logger.info("Synced \(mindfulSamples.count) mindfulness sessions")
                } catch {
                    logger.error("Failed to save mindfulness data: \(error.localizedDescription)")
                }
            }

            healthStore.execute(query)
        }
    }
    
    // MARK: - Vital Signs Sync
    
    private func syncVitalSigns(userId: String, context: ModelContext) async {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -1, to: endDate) else {
            logger.error("Failed to calculate start date for vital signs sync")
            return
        }
        
        // Sync heart rate
        await syncQuantityData(
            type: .heartRate,
            metricType: .heartRate,
            userId: userId,
            startDate: startDate,
            endDate: endDate,
            context: context
        )
        
        // Sync weight
        await syncQuantityData(
            type: .bodyMass,
            metricType: .weight,
            userId: userId,
            startDate: startDate,
            endDate: endDate,
            context: context
        )
    }
    
    // MARK: - Health Goals Integration
    
    func createHealthGoal(
        userId: String,
        metricType: HealthMetricType,
        targetValue: Double,
        frequency: HealthGoalFrequency,
        context: ModelContext
    ) -> HealthGoal {
        let goal = HealthGoal(userId: userId, metricType: metricType, targetValue: targetValue)
        goal.frequency = frequency
        
        context.insert(goal)
        
        do {
            try context.save()
            logger.info("Created health goal: \(metricType.displayName) - \(targetValue)")
        } catch {
            logger.error("Failed to create health goal: \(error.localizedDescription)")
        }
        
        return goal
    }
    
    func updateHealthGoalProgress(userId: String, context: ModelContext) async {
        let descriptor = FetchDescriptor<HealthGoal>(
            predicate: #Predicate { $0.userId == userId && $0.isActive }
        )
        
        let goals = (try? context.fetch(descriptor)) ?? []
        
        for goal in goals {
            let currentValue = await getCurrentMetricValue(
                metricType: goal.metricType,
                userId: userId,
                context: context
            )
            
            goal.updateProgress(value: currentValue)
            
            // Create reminder if goal not met and reminder enabled
            if goal.reminderEnabled && !goal.isAchieved && shouldCreateReminder(for: goal) {
                await createHealthGoalReminder(goal: goal, context: context)
            }
        }
        
        do {
            try context.save()
        } catch {
            logger.error("Failed to update health goal progress: \(error.localizedDescription)")
        }
    }
    
    private func getCurrentMetricValue(metricType: HealthMetricType, userId: String, context: ModelContext) async -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            logger.error("Failed to calculate tomorrow date for metric value")
            return 0
        }
        
        let descriptor = FetchDescriptor<HealthMetric>(
            predicate: #Predicate<HealthMetric> { metric in
                metric.userId == userId &&
                metric.type == metricType &&
                metric.date >= today &&
                metric.date < tomorrow
            }
        )
        
        let metrics = (try? context.fetch(descriptor)) ?? []
        return metrics.reduce(0) { $0 + $1.value }
    }
    
    private func shouldCreateReminder(for goal: HealthGoal) -> Bool {
        // Logic to determine if a reminder should be created
        // For example, only create one reminder per day
        let calendar = Calendar.current
        
        if let lastReminder = goal.reminders?.last {
            return !calendar.isDateInToday(lastReminder.createdAt)
        }
        
        return true
    }
    
    private func createHealthGoalReminder(goal: HealthGoal, context: ModelContext) async {
        let reminderTitle = "Health Goal Reminder"
        let reminderDetails = "You're at \(Int(goal.progress * 100))% of your \(goal.metricType.displayName) goal. Keep going!"

        do {
            let reminder = try await ReminderCreationService.shared.createReminder(
                request: .init(
                    title: reminderTitle,
                    details: reminderDetails,
                    dueDate: Date().addingTimeInterval(3600),
                    priority: .medium,
                    useNaturalLanguageParsing: false
                ),
                in: context
            )
            goal.reminders?.append(reminder)
            logger.info("Created health goal reminder for: \(goal.metricType.displayName)")
        } catch {
            logger.error("Failed to create health goal reminder: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Background Delivery
    
    private func setupBackgroundDelivery() {
        guard hasPermission else { return }
        
        let typesToObserve: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .heartRate
        ]
        
        for typeIdentifier in typesToObserve {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else { continue }
            
            healthStore.enableBackgroundDelivery(for: quantityType, frequency: .hourly) { [weak self] success, error in
                if success {
                    self?.logger.info("Enabled background delivery for \(typeIdentifier.rawValue)")
                } else if let error = error {
                    self?.logger.error("Failed to enable background delivery for \(typeIdentifier.rawValue): \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getUnit(for identifier: HKQuantityTypeIdentifier) -> HKUnit {
        Self.healthUnit(for: identifier)
    }

    nonisolated private static func healthUnit(for identifier: HKQuantityTypeIdentifier) -> HKUnit {
        switch identifier {
        case .stepCount:
            return .count()
        case .distanceWalkingRunning:
            return .meter()
        case .flightsClimbed:
            return .count()
        case .activeEnergyBurned, .basalEnergyBurned:
            return .kilocalorie()
        case .heartRate:
            return HKUnit.count().unitDivided(by: .minute())
        case .bodyMass:
            return .gramUnit(with: .kilo)
        case .bodyMassIndex:
            return HKUnit.count()
        case .dietaryWater:
            return .literUnit(with: .milli)
        default:
            return .count()
        }
    }
    
    private func mapWorkoutType(_ hkWorkoutType: HKWorkoutActivityType) -> WorkoutType {
        Self.mapWorkoutTypeStatic(hkWorkoutType)
    }

    nonisolated private static func mapWorkoutTypeStatic(_ hkWorkoutType: HKWorkoutActivityType) -> WorkoutType {
        switch hkWorkoutType {
        case .running: return .running
        case .walking: return .walking
        case .cycling: return .cycling
        case .swimming: return .swimming
        case .yoga: return .yoga
        case .traditionalStrengthTraining: return .strength
        case .highIntensityIntervalTraining: return .hiit
        case .socialDance, .cardioDance, .dance: return .dance
        case .pilates: return .pilates
        case .boxing: return .boxing
        case .tennis: return .tennis
        case .basketball: return .basketball
        case .soccer: return .soccer
        default: return .other
        }
    }

    nonisolated private static func activeEnergyKilocalories(for workout: HKWorkout) -> Double {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return 0
        }

        return workout
            .statistics(for: energyType)?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie()) ?? 0
    }

    nonisolated private static func distanceType(for workoutType: WorkoutType) -> HKQuantityType? {
        switch workoutType {
        case .cycling:
            return HKQuantityType.quantityType(forIdentifier: .distanceCycling)
        case .swimming:
            return HKQuantityType.quantityType(forIdentifier: .distanceSwimming)
        case .running, .walking, .tennis, .basketball, .soccer, .other:
            return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .yoga, .strength, .hiit, .dance, .pilates, .boxing:
            return nil
        }
    }
    
    // MARK: - Data Writing
    
    func writeWorkout(
        workoutType: WorkoutType,
        startDate: Date,
        endDate: Date,
        calories: Double,
        distance: Double
    ) async -> Bool {
        guard hasPermission else { return false }
        
        let hkWorkoutType = workoutType.healthKitWorkoutType

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = hkWorkoutType
        configuration.locationType = .unknown

        do {
            let builder = HKWorkoutBuilder(
                healthStore: healthStore,
                configuration: configuration,
                device: .local()
            )

            try await builder.beginCollection(at: startDate)

            var samples: [HKSample] = []
            if calories > 0,
               let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                samples.append(
                    HKQuantitySample(
                        type: energyType,
                        quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
                        start: startDate,
                        end: endDate
                    )
                )
            }

            if distance > 0,
               let distanceType = Self.distanceType(for: workoutType) {
                samples.append(
                    HKQuantitySample(
                        type: distanceType,
                        quantity: HKQuantity(unit: .meter(), doubleValue: distance),
                        start: startDate,
                        end: endDate
                    )
                )
            }

            if !samples.isEmpty {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    builder.add(samples) { success, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else if success {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: CocoaError(.coderInvalidValue))
                        }
                    }
                }
            }

            try await builder.endCollection(at: endDate)
            _ = try await builder.finishWorkout()
            logger.info("Saved workout to HealthKit: \(workoutType.displayName)")
            return true
        } catch {
            logger.error("Failed to save workout to HealthKit: \(error.localizedDescription)")
            return false
        }
    }
    
    func writeMindfulnessSession(startDate: Date, endDate: Date) async -> Bool {
        guard hasPermission else { return false }
        
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return false }
        
        let mindfulSample = HKCategorySample(
            type: mindfulType,
            value: 0, // HKCategoryValue for mindfulness session
            start: startDate,
            end: endDate
        )
        
        do {
            try await healthStore.save(mindfulSample)
            logger.info("Saved mindfulness session to HealthKit")
            return true
        } catch {
            logger.error("Failed to save mindfulness session to HealthKit: \(error.localizedDescription)")
            return false
        }
    }
}
