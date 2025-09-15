//
//  HealthModels.swift
//  a-do
//
//  HealthKit integration models
//

import Foundation
import SwiftData
import HealthKit

// MARK: - Health Integration Configuration
@Model
final class HealthIntegrationConfiguration {
    var id: UUID = UUID()
    var userId: String = ""
    var isEnabled: Bool = false
    var hasHealthKitPermission: Bool = false
    var syncHabits: Bool = true
    var syncWorkouts: Bool = true
    var syncMindfulness: Bool = true
    var syncSleep: Bool = true
    var syncNutrition: Bool = false
    var syncVitals: Bool = false
    var autoCreateReminders: Bool = true
    var reminderLeadTime: TimeInterval = 1800 // 30 minutes
    var lastSyncDate: Date?
    var syncFrequency: HealthSyncFrequency = HealthSyncFrequency.hourly
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(userId: String) {
        self.userId = userId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func updateSettings() {
        updatedAt = Date()
    }
}

// MARK: - Health Sync Frequency
enum HealthSyncFrequency: String, CaseIterable, Codable {
    case realtime = "realtime"
    case hourly = "hourly"
    case daily = "daily"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .realtime: return "Real-time"
        case .hourly: return "Hourly"
        case .daily: return "Daily"
        case .manual: return "Manual Only"
        }
    }
    
    var interval: TimeInterval? {
        switch self {
        case .realtime: return nil
        case .hourly: return 3600
        case .daily: return 86400
        case .manual: return nil
        }
    }
}

// MARK: - Health Metric
@Model
final class HealthMetric {
    var id: UUID = UUID()
    var userId: String = ""
    var type: HealthMetricType = HealthMetricType.steps
    var value: Double = 0.0
    var unit: String = ""
    var date: Date = Date()
    var source: String = ""
    var isManualEntry: Bool = false
    var syncedAt: Date = Date()
    
    // Relationships
    @Relationship(deleteRule: .nullify) var habit: Habit?
    @Relationship(deleteRule: .nullify) var reminder: Reminder?
    
    init(type: HealthMetricType, value: Double, unit: String, date: Date = Date()) {
        self.type = type
        self.value = value
        self.unit = unit
        self.date = date
        self.syncedAt = Date()
    }
    
    var formattedValue: String {
        switch type {
        case .steps, .flightsClimbed:
            return String(format: "%.0f", value)
        case .distance:
            return String(format: "%.2f", value)
        case .activeEnergy, .restingEnergy:
            return String(format: "%.0f", value)
        case .heartRate:
            return String(format: "%.0f", value)
        case .sleepHours:
            return String(format: "%.1f", value)
        case .mindfulMinutes:
            return String(format: "%.0f", value)
        case .workoutDuration:
            return String(format: "%.0f", value)
        case .weight, .bodyMassIndex:
            return String(format: "%.1f", value)
        case .bloodPressureSystolic, .bloodPressureDiastolic:
            return String(format: "%.0f", value)
        case .waterIntake:
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Health Metric Type
enum HealthMetricType: String, CaseIterable, Codable {
    // Activity
    case steps = "steps"
    case distance = "distance"
    case flightsClimbed = "flights_climbed"
    case activeEnergy = "active_energy"
    case restingEnergy = "resting_energy"
    case workoutDuration = "workout_duration"
    
    // Vitals
    case heartRate = "heart_rate"
    case bloodPressureSystolic = "blood_pressure_systolic"
    case bloodPressureDiastolic = "blood_pressure_diastolic"
    
    // Body Measurements
    case weight = "weight"
    case bodyMassIndex = "body_mass_index"
    
    // Sleep & Mindfulness
    case sleepHours = "sleep_hours"
    case mindfulMinutes = "mindful_minutes"
    
    // Nutrition
    case waterIntake = "water_intake"
    
    var displayName: String {
        switch self {
        case .steps: return "Steps"
        case .distance: return "Distance"
        case .flightsClimbed: return "Flights Climbed"
        case .activeEnergy: return "Active Energy"
        case .restingEnergy: return "Resting Energy"
        case .workoutDuration: return "Workout Duration"
        case .heartRate: return "Heart Rate"
        case .bloodPressureSystolic: return "Blood Pressure (Systolic)"
        case .bloodPressureDiastolic: return "Blood Pressure (Diastolic)"
        case .weight: return "Weight"
        case .bodyMassIndex: return "BMI"
        case .sleepHours: return "Sleep Hours"
        case .mindfulMinutes: return "Mindful Minutes"
        case .waterIntake: return "Water Intake"
        }
    }
    
    var icon: String {
        switch self {
        case .steps: return "figure.walk"
        case .distance: return "location"
        case .flightsClimbed: return "figure.stairs"
        case .activeEnergy: return "flame"
        case .restingEnergy: return "flame.fill"
        case .workoutDuration: return "timer"
        case .heartRate: return "heart"
        case .bloodPressureSystolic, .bloodPressureDiastolic: return "heart.text.square"
        case .weight: return "scalemass"
        case .bodyMassIndex: return "person"
        case .sleepHours: return "bed.double"
        case .mindfulMinutes: return "brain.head.profile"
        case .waterIntake: return "drop"
        }
    }
    
    var defaultUnit: String {
        switch self {
        case .steps: return "steps"
        case .distance: return "km"
        case .flightsClimbed: return "flights"
        case .activeEnergy, .restingEnergy: return "kcal"
        case .workoutDuration: return "min"
        case .heartRate: return "bpm"
        case .bloodPressureSystolic, .bloodPressureDiastolic: return "mmHg"
        case .weight: return "kg"
        case .bodyMassIndex: return "kg/m²"
        case .sleepHours: return "hours"
        case .mindfulMinutes: return "min"
        case .waterIntake: return "ml"
        }
    }
    
    var healthKitIdentifier: HKQuantityTypeIdentifier? {
        switch self {
        case .steps: return .stepCount
        case .distance: return .distanceWalkingRunning
        case .flightsClimbed: return .flightsClimbed
        case .activeEnergy: return .activeEnergyBurned
        case .restingEnergy: return .basalEnergyBurned
        case .heartRate: return .heartRate
        case .bloodPressureSystolic: return .bloodPressureSystolic
        case .bloodPressureDiastolic: return .bloodPressureDiastolic
        case .weight: return .bodyMass
        case .bodyMassIndex: return .bodyMassIndex
        case .waterIntake: return .dietaryWater
        case .workoutDuration, .sleepHours, .mindfulMinutes: return nil
        }
    }
}

// MARK: - Health Goal
@Model
final class HealthGoal {
    var id: UUID = UUID()
    var userId: String = ""
    var metricType: HealthMetricType = HealthMetricType.steps
    var targetValue: Double = 10000
    var currentValue: Double = 0
    var unit: String = "steps"
    var frequency: HealthGoalFrequency = HealthGoalFrequency.daily
    var startDate: Date = Date()
    var endDate: Date?
    var isActive: Bool = true
    var isCompleted: Bool = false
    var completedAt: Date?
    var streak: Int = 0
    var bestStreak: Int = 0
    var lastUpdated: Date = Date()
    var reminderEnabled: Bool = true
    var reminderTime: Date?
    var celebrationEnabled: Bool = true
    
    // Relationships
    @Relationship(deleteRule: .cascade) var reminders: [Reminder] = []
    @Relationship(deleteRule: .nullify) var linkedHabit: Habit?
    
    init(userId: String, metricType: HealthMetricType, targetValue: Double) {
        self.userId = userId
        self.metricType = metricType
        self.targetValue = targetValue
        self.unit = metricType.defaultUnit
        self.startDate = Date()
        self.lastUpdated = Date()
    }
    
    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(1.0, currentValue / targetValue)
    }
    
    var isAchieved: Bool {
        return currentValue >= targetValue
    }
    
    func updateProgress(value: Double) {
        let wasAchieved = isAchieved
        currentValue = value
        lastUpdated = Date()
        
        if isAchieved && !wasAchieved {
            // Goal just achieved
            if !isCompleted {
                complete()
            }
        }
    }
    
    func complete() {
        isCompleted = true
        completedAt = Date()
        streak += 1
        bestStreak = max(bestStreak, streak)
    }
    
    func reset() {
        currentValue = 0
        isCompleted = false
        completedAt = nil
        lastUpdated = Date()
    }
    
    func resetStreak() {
        streak = 0
    }
}

// MARK: - Health Goal Frequency
enum HealthGoalFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

// MARK: - Workout Integration
@Model
final class WorkoutIntegration {
    var id: UUID = UUID()
    var userId: String = ""
    var workoutType: WorkoutType = WorkoutType.running
    var name: String = ""
    var startDate: Date = Date()
    var endDate: Date?
    var duration: TimeInterval = 0
    var calories: Double = 0
    var distance: Double = 0
    var averageHeartRate: Double = 0
    var maxHeartRate: Double = 0
    var isCompleted: Bool = false
    var source: String = "HealthKit"
    var healthKitUUID: String?
    var syncedAt: Date = Date()
    
    // Relationships
    @Relationship(deleteRule: .cascade) var reminders: [Reminder] = []
    @Relationship(deleteRule: .nullify) var linkedHabit: Habit?
    
    init(workoutType: WorkoutType, name: String, startDate: Date = Date()) {
        self.workoutType = workoutType
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.startDate = startDate
        self.syncedAt = Date()
    }
    
    func complete(endDate: Date, calories: Double, distance: Double) {
        self.endDate = endDate
        self.duration = endDate.timeIntervalSince(startDate)
        self.calories = calories
        self.distance = distance
        self.isCompleted = true
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var formattedDistance: String {
        return String(format: "%.2f km", distance / 1000)
    }
    
    var formattedCalories: String {
        return String(format: "%.0f kcal", calories)
    }
}

// MARK: - Workout Type
enum WorkoutType: String, CaseIterable, Codable {
    case running = "running"
    case walking = "walking"
    case cycling = "cycling"
    case swimming = "swimming"
    case yoga = "yoga"
    case strength = "strength"
    case hiit = "hiit"
    case dance = "dance"
    case pilates = "pilates"
    case boxing = "boxing"
    case tennis = "tennis"
    case basketball = "basketball"
    case soccer = "soccer"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .strength: return "Strength Training"
        case .hiit: return "HIIT"
        case .dance: return "Dance"
        case .pilates: return "Pilates"
        case .boxing: return "Boxing"
        case .tennis: return "Tennis"
        case .basketball: return "Basketball"
        case .soccer: return "Soccer"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.yoga"
        case .strength: return "dumbbell"
        case .hiit: return "timer"
        case .dance: return "music.note"
        case .pilates: return "figure.flexibility"
        case .boxing: return "figure.boxing"
        case .tennis: return "tennis.racket"
        case .basketball: return "basketball"
        case .soccer: return "soccerball"
        case .other: return "figure.mixed.cardio"
        }
    }
    
    var healthKitWorkoutType: HKWorkoutActivityType {
        switch self {
        case .running: return .running
        case .walking: return .walking
        case .cycling: return .cycling
        case .swimming: return .swimming
        case .yoga: return .yoga
        case .strength: return .traditionalStrengthTraining
        case .hiit: return .highIntensityIntervalTraining
        case .dance: return .dance
        case .pilates: return .pilates
        case .boxing: return .boxing
        case .tennis: return .tennis
        case .basketball: return .basketball
        case .soccer: return .soccer
        case .other: return .other
        }
    }
}

// MARK: - Sleep Integration
@Model
final class SleepIntegration {
    var id: UUID = UUID()
    var userId: String = ""
    var bedtime: Date = Date()
    var wakeTime: Date = Date()
    var sleepDuration: TimeInterval = 0
    var sleepQuality: SleepQuality = SleepQuality.good
    var deepSleepDuration: TimeInterval = 0
    var remSleepDuration: TimeInterval = 0
    var restfulnessScore: Double = 0
    var source: String = "HealthKit"
    var healthKitUUID: String?
    var syncedAt: Date = Date()
    
    // Relationships
    @Relationship(deleteRule: .cascade) var reminders: [Reminder] = []
    @Relationship(deleteRule: .nullify) var linkedHabit: Habit?
    
    init(bedtime: Date, wakeTime: Date) {
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.sleepDuration = wakeTime.timeIntervalSince(bedtime)
        self.syncedAt = Date()
    }
    
    var formattedSleepDuration: String {
        let hours = Int(sleepDuration) / 3600
        let minutes = Int(sleepDuration) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }
    
    var sleepEfficiency: Double {
        guard sleepDuration > 0 else { return 0 }
        let timeInBed = wakeTime.timeIntervalSince(bedtime)
        return sleepDuration / timeInBed
    }
}

// MARK: - Sleep Quality
enum SleepQuality: String, CaseIterable, Codable {
    case poor = "poor"
    case fair = "fair"
    case good = "good"
    case excellent = "excellent"
    
    var displayName: String {
        switch self {
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
    
    var color: String {
        switch self {
        case .poor: return "#FF3B30"
        case .fair: return "#FF9500"
        case .good: return "#34C759"
        case .excellent: return "#007AFF"
        }
    }
    
    var score: Double {
        switch self {
        case .poor: return 1.0
        case .fair: return 2.0
        case .good: return 3.0
        case .excellent: return 4.0
        }
    }
}

// MARK: - Mindfulness Integration
@Model
final class MindfulnessIntegration {
    var id: UUID = UUID()
    var userId: String = ""
    var sessionType: MindfulnessType = MindfulnessType.meditation
    var startDate: Date = Date()
    var endDate: Date?
    var duration: TimeInterval = 0
    var isCompleted: Bool = false
    var notes: String = ""
    var moodBefore: MoodLevel = MoodLevel.neutral
    var moodAfter: MoodLevel = MoodLevel.neutral
    var source: String = "HealthKit"
    var healthKitUUID: String?
    var syncedAt: Date = Date()
    
    // Relationships
    @Relationship(deleteRule: .cascade) var reminders: [Reminder] = []
    @Relationship(deleteRule: .nullify) var linkedHabit: Habit?
    
    init(sessionType: MindfulnessType, startDate: Date = Date()) {
        self.sessionType = sessionType
        self.startDate = startDate
        self.syncedAt = Date()
    }
    
    func complete(endDate: Date, moodAfter: MoodLevel) {
        self.endDate = endDate
        self.duration = endDate.timeIntervalSince(startDate)
        self.moodAfter = moodAfter
        self.isCompleted = true
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    var moodImprovement: Double {
        return moodAfter.score - moodBefore.score
    }
}

// MARK: - Mindfulness Type
enum MindfulnessType: String, CaseIterable, Codable {
    case meditation = "meditation"
    case breathing = "breathing"
    case bodyScanning = "body_scanning"
    case mindfulWalking = "mindful_walking"
    case gratitude = "gratitude"
    case visualization = "visualization"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .meditation: return "Meditation"
        case .breathing: return "Breathing Exercise"
        case .bodyScanning: return "Body Scanning"
        case .mindfulWalking: return "Mindful Walking"
        case .gratitude: return "Gratitude Practice"
        case .visualization: return "Visualization"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .meditation: return "brain.head.profile"
        case .breathing: return "lungs"
        case .bodyScanning: return "figure.mind.and.body"
        case .mindfulWalking: return "figure.walk"
        case .gratitude: return "heart"
        case .visualization: return "eye"
        case .other: return "sparkles"
        }
    }
}

// MARK: - Mood Level
enum MoodLevel: String, CaseIterable, Codable {
    case veryPoor = "very_poor"
    case poor = "poor"
    case neutral = "neutral"
    case good = "good"
    case excellent = "excellent"
    
    var displayName: String {
        switch self {
        case .veryPoor: return "Very Poor"
        case .poor: return "Poor"
        case .neutral: return "Neutral"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
    
    var emoji: String {
        switch self {
        case .veryPoor: return "😞"
        case .poor: return "😕"
        case .neutral: return "😐"
        case .good: return "🙂"
        case .excellent: return "😊"
        }
    }
    
    var score: Double {
        switch self {
        case .veryPoor: return 1.0
        case .poor: return 2.0
        case .neutral: return 3.0
        case .good: return 4.0
        case .excellent: return 5.0
        }
    }
    
    var color: String {
        switch self {
        case .veryPoor: return "#FF3B30"
        case .poor: return "#FF9500"
        case .neutral: return "#8E8E93"
        case .good: return "#34C759"
        case .excellent: return "#007AFF"
        }
    }
}

// MARK: - Health Reminder Template
@Model
final class HealthReminderTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var healthDescription: String = ""
    var metricType: HealthMetricType = HealthMetricType.steps
    var triggerCondition: HealthTriggerCondition = HealthTriggerCondition.goalNotMet
    var triggerValue: Double = 0
    var reminderText: String = ""
    var isActive: Bool = true
    var usageCount: Int = 0
    var lastUsed: Date?
    var createdAt: Date = Date()
    
    init(name: String, metricType: HealthMetricType, triggerCondition: HealthTriggerCondition) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.metricType = metricType
        self.triggerCondition = triggerCondition
        self.createdAt = Date()
    }
    
    func updateUsage() {
        usageCount += 1
        lastUsed = Date()
    }
}

// MARK: - Health Trigger Condition
enum HealthTriggerCondition: String, CaseIterable, Codable {
    case goalNotMet = "goal_not_met"
    case valueBelow = "value_below"
    case valueAbove = "value_above"
    case noDataToday = "no_data_today"
    case streakBroken = "streak_broken"
    case timeOfDay = "time_of_day"
    
    var displayName: String {
        switch self {
        case .goalNotMet: return "Goal Not Met"
        case .valueBelow: return "Value Below Threshold"
        case .valueAbove: return "Value Above Threshold"
        case .noDataToday: return "No Data Today"
        case .streakBroken: return "Streak Broken"
        case .timeOfDay: return "Time of Day"
        }
    }
}
