//
//  GamificationManager.swift
//  a-do
//
//  Gamification and achievement system manager
//

import Foundation
import SwiftData
import Observation
import os

@MainActor
@Observable
final class GamificationManager {
    static let shared = GamificationManager()
    
    private let logger = Logger(subsystem: "a-do", category: "Gamification")

    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.isProUser
    }

    // Current user profile
    var currentProfile: UserProfile?
    
    // Processing state
    var isProcessing: Bool = false
    var lastUpdateDate: Date?
    
    // Recent achievements and rewards
    var recentAchievements: [UserAchievement] = []
    var pendingRewards: [UserReward] = []
    
    private init() {
        setupPeriodicUpdates()
    }
    
    // MARK: - Profile Management
    
    func getUserProfile(userId: String, displayName: String, context: ModelContext) -> UserProfile {
        if let profile = currentProfile, profile.userId == userId {
            return profile
        }
        
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.userId == userId }
        )
        
        if let existingProfile = try? context.fetch(descriptor).first {
            currentProfile = existingProfile
            return existingProfile
        }
        
        // Create new profile
        let newProfile = UserProfile(userId: userId, displayName: displayName)
        context.insert(newProfile)
        
        // Initialize with default achievements
        initializeDefaultAchievements(for: newProfile, context: context)
        
        do {
            try context.save()
            currentProfile = newProfile
            logger.info("Created user profile for: \(displayName)")
        } catch {
            logger.error("Failed to create user profile: \(error.localizedDescription)")
        }
        
        return newProfile
    }
    
    private func initializeDefaultAchievements(for profile: UserProfile, context: ModelContext) {
        let defaultAchievements = createDefaultAchievements(context: context)
        
        for achievement in defaultAchievements {
            let userAchievement = UserAchievement(achievement: achievement, userProfile: profile)
            profile.achievements?.append(userAchievement)
            context.insert(userAchievement)
        }
    }
    
    // MARK: - Achievement System
    
    func checkAchievements(for profile: UserProfile, context: ModelContext) async {
        guard isProEnabled else {
            logger.warning("Gamification achievements is a Pro feature")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        logger.info("Checking achievements for user: \(profile.displayName)")
        
        let incompleteAchievements = (profile.achievements ?? []).filter { !$0.isCompleted }
        
        for userAchievement in incompleteAchievements {
            guard let achievement = userAchievement.achievement else { continue }
            
            let progress = await calculateAchievementProgress(achievement, profile: profile, context: context)
            userAchievement.updateProgress(progress)
            
            if userAchievement.isCompleted && !userAchievement.notificationSent {
                await notifyAchievementUnlocked(userAchievement)
                recentAchievements.append(userAchievement)
                userAchievement.notificationSent = true
            }
        }
        
        do {
            try context.save()
            lastUpdateDate = Date()
        } catch {
            logger.error("Failed to update achievements: \(error.localizedDescription)")
        }
    }
    
    private func calculateAchievementProgress(_ achievement: Achievement, profile: UserProfile, context: ModelContext) async -> Double {
        switch achievement.category {
        case .productivity:
            return await calculateProductivityProgress(achievement, profile: profile)
        case .habits:
            return await calculateHabitsProgress(achievement, profile: profile)
        case .focus:
            return await calculateFocusProgress(achievement, profile: profile)
        case .streaks:
            return await calculateStreaksProgress(achievement, profile: profile)
        case .milestones:
            return await calculateMilestonesProgress(achievement, profile: profile)
        case .social:
            return await calculateSocialProgress(achievement, profile: profile, context: context)
        case .special, .seasonal:
            return await calculateSpecialProgress(achievement, profile: profile)
        }
    }
    
    private func calculateProductivityProgress(_ achievement: Achievement, profile: UserProfile) async -> Double {
        // Example achievement requirements
        switch achievement.name {
        case "First Steps":
            return profile.totalRemindersCompleted >= 1 ? 1.0 : 0.0
        case "Getting Started":
            return min(1.0, Double(profile.totalRemindersCompleted) / 10.0)
        case "Productive":
            return min(1.0, Double(profile.totalRemindersCompleted) / 50.0)
        case "Super Productive":
            return min(1.0, Double(profile.totalRemindersCompleted) / 100.0)
        case "Productivity Master":
            return min(1.0, Double(profile.totalRemindersCompleted) / 500.0)
        default:
            return 0.0
        }
    }
    
    private func calculateHabitsProgress(_ achievement: Achievement, profile: UserProfile) async -> Double {
        switch achievement.name {
        case "Habit Starter":
            return profile.totalHabitsCompleted >= 1 ? 1.0 : 0.0
        case "Habit Builder":
            return min(1.0, Double(profile.totalHabitsCompleted) / 25.0)
        case "Habit Master":
            return min(1.0, Double(profile.totalHabitsCompleted) / 100.0)
        default:
            return 0.0
        }
    }
    
    private func calculateFocusProgress(_ achievement: Achievement, profile: UserProfile) async -> Double {
        let focusHours = profile.totalFocusTime / 3600
        
        switch achievement.name {
        case "First Focus":
            return focusHours >= 1 ? 1.0 : 0.0
        case "Focus Enthusiast":
            return min(1.0, focusHours / 10.0)
        case "Focus Master":
            return min(1.0, focusHours / 50.0)
        case "Zen Master":
            return min(1.0, focusHours / 100.0)
        default:
            return 0.0
        }
    }
    
    private func calculateStreaksProgress(_ achievement: Achievement, profile: UserProfile) async -> Double {
        switch achievement.name {
        case "Streak Starter":
            return profile.streak >= 3 ? 1.0 : min(1.0, Double(profile.streak) / 3.0)
        case "Week Warrior":
            return profile.streak >= 7 ? 1.0 : min(1.0, Double(profile.streak) / 7.0)
        case "Month Master":
            return profile.streak >= 30 ? 1.0 : min(1.0, Double(profile.streak) / 30.0)
        case "Legendary Streak":
            return profile.longestStreak >= 100 ? 1.0 : min(1.0, Double(profile.longestStreak) / 100.0)
        default:
            return 0.0
        }
    }
    
    private func calculateMilestonesProgress(_ achievement: Achievement, profile: UserProfile) async -> Double {
        switch achievement.name {
        case "Level Up":
            return profile.level >= 5 ? 1.0 : min(1.0, Double(profile.level) / 5.0)
        case "Experienced":
            return profile.level >= 10 ? 1.0 : min(1.0, Double(profile.level) / 10.0)
        case "Expert":
            return profile.level >= 25 ? 1.0 : min(1.0, Double(profile.level) / 25.0)
        case "Master":
            return profile.level >= 50 ? 1.0 : min(1.0, Double(profile.level) / 50.0)
        default:
            return 0.0
        }
    }
    
    private func calculateSocialProgress(_ achievement: Achievement, profile: UserProfile, context: ModelContext) async -> Double {
        // This would calculate social achievements based on collaboration features
        let workspaces = (try? context.fetch(FetchDescriptor<Workspace>())) ?? []
        let sharedReminders = (try? context.fetch(FetchDescriptor<SharedReminder>())) ?? []
        
        switch achievement.name {
        case "Team Player":
            return min(Double(workspaces.count) / 3.0, 1.0)
        case "Sharing Champion":
            return min(Double(sharedReminders.count) / 10.0, 1.0)
        case "Collaboration Master":
            let totalCollaborations = workspaces.count + sharedReminders.count
            return min(Double(totalCollaborations) / 15.0, 1.0)
        default:
            return 0.0
        }
    }
    
    private func calculateSpecialProgress(_ achievement: Achievement, profile: UserProfile) async -> Double {
        switch achievement.name {
        case "Perfect Day":
            return profile.perfectDays >= 1 ? 1.0 : 0.0
        case "Early Bird":
            // Check if user completes tasks before 9 AM
            return 0.0 // Would need additional tracking
        case "Night Owl":
            // Check if user completes tasks after 9 PM
            return 0.0 // Would need additional tracking
        default:
            return 0.0
        }
    }
    
    // MARK: - Experience and Rewards
    
    func recordReminderCompletion(for profile: UserProfile, context: ModelContext) async {
        profile.recordReminderCompletion()
        profile.updateStreak(completed: true)
        
        await checkAchievements(for: profile, context: context)
        await checkDailyRewards(for: profile, context: context)
        
        do {
            try context.save()
        } catch {
            logger.error("Failed to record reminder completion: \(error.localizedDescription)")
        }
    }
    
    func recordHabitCompletion(for profile: UserProfile, context: ModelContext) async {
        profile.recordHabitCompletion()
        profile.updateStreak(completed: true)
        
        await checkAchievements(for: profile, context: context)
        await checkDailyRewards(for: profile, context: context)
        
        do {
            try context.save()
        } catch {
            logger.error("Failed to record habit completion: \(error.localizedDescription)")
        }
    }
    
    func recordFocusSession(duration: TimeInterval, for profile: UserProfile, context: ModelContext) async {
        profile.recordFocusTime(duration)
        
        await checkAchievements(for: profile, context: context)
        
        do {
            try context.save()
        } catch {
            logger.error("Failed to record focus session: \(error.localizedDescription)")
        }
    }
    
    func recordPerfectDay(for profile: UserProfile, context: ModelContext) async {
        profile.recordPerfectDay()
        
        // Award perfect day badge
        await awardPerfectDayBadge(for: profile, context: context)
        
        await checkAchievements(for: profile, context: context)
        
        do {
            try context.save()
        } catch {
            logger.error("Failed to record perfect day: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Challenge System
    
    func joinChallenge(_ challenge: Challenge, profile: UserProfile, context: ModelContext) -> UserChallenge? {
        // Check if already joined
        let existingChallenge = profile.challenges?.first { $0.challengeId == challenge.id }
        if existingChallenge != nil {
            return existingChallenge
        }
        
        let userChallenge = UserChallenge(challenge: challenge, userProfile: profile)
        profile.challenges?.append(userChallenge)
        context.insert(userChallenge)
        
        challenge.join()
        
        do {
            try context.save()
            logger.info("User joined challenge: \(challenge.name)")
            return userChallenge
        } catch {
            logger.error("Failed to join challenge: \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateChallengeProgress(_ userChallenge: UserChallenge, progress: Double, context: ModelContext) {
        userChallenge.updateProgress(progress)
        
        if userChallenge.isCompleted {
            // Award challenge completion rewards
            awardChallengeRewards(userChallenge, context: context)
        }
        
        do {
            try context.save()
        } catch {
            logger.error("Failed to update challenge progress: \(error.localizedDescription)")
        }
    }
    
    private func awardChallengeRewards(_ userChallenge: UserChallenge, context: ModelContext) {
        guard let challenge = userChallenge.challenge,
              let profile = userChallenge.userProfile else { return }
        
        let reward = UserReward(
            type: .coins,
            title: "Challenge Complete!",
            description: "You completed the \(challenge.name) challenge!",
            coins: Int(50.0 * challenge.difficulty.multiplier),
            gems: challenge.difficulty == .extreme ? 5 : 0,
            experience: Int(100.0 * challenge.difficulty.multiplier),
            userProfile: profile
        )
        
        profile.rewards?.append(reward)
        pendingRewards.append(reward)
        context.insert(reward)
    }
    
    // MARK: - Reward System
    
    func purchaseReward(_ reward: Reward, profile: UserProfile, context: ModelContext) -> Bool {
        guard reward.isAvailable else { return false }
        
        // Check if user has enough currency
        switch reward.currency {
        case .coins:
            guard profile.spendCoins(reward.cost) else { return false }
        case .gems:
            guard profile.spendGems(reward.cost) else { return false }
        case .experience:
            // Experience can't be spent, only awarded
            return false
        }
        
        // Award the reward
        let userReward = UserReward(
            type: reward.type,
            title: reward.name,
            description: reward.rewardDescription,
            userProfile: profile
        )
        
        profile.rewards?.append(userReward)
        pendingRewards.append(userReward)
        context.insert(userReward)
        
        reward.purchase()
        
        do {
            try context.save()
            logger.info("User purchased reward: \(reward.name)")
            return true
        } catch {
            logger.error("Failed to purchase reward: \(error.localizedDescription)")
            return false
        }
    }
    
    func collectReward(_ userReward: UserReward, context: ModelContext) -> Bool {
        guard !userReward.isCollected && !userReward.isExpired else { return false }
        
        userReward.collect()
        
        // Remove from pending rewards
        pendingRewards.removeAll { $0.id == userReward.id }
        
        do {
            try context.save()
            logger.info("User collected reward: \(userReward.title)")
            return true
        } catch {
            logger.error("Failed to collect reward: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Daily Rewards
    
    private func checkDailyRewards(for profile: UserProfile, context: ModelContext) async {
        let calendar = Calendar.current
        
        // Check if user has already received daily reward today
        let today = calendar.startOfDay(for: Date())
        let hasReceivedToday = (profile.rewards ?? []).contains { reward in
            let awardedAt = reward.awardedAt
            return calendar.isDate(awardedAt, inSameDayAs: today) && reward.type == .coins
        }
        
        if !hasReceivedToday {
            let dailyReward = UserReward(
                type: .coins,
                title: "Daily Bonus",
                description: "Your daily login bonus!",
                coins: 10 + (profile.streak * 2), // Bonus coins for streak
                userProfile: profile
            )
            
            profile.rewards?.append(dailyReward)
            pendingRewards.append(dailyReward)
            context.insert(dailyReward)
        }
    }
    
    // MARK: - Badge System
    
    private func awardPerfectDayBadge(for profile: UserProfile, context: ModelContext) async {
        // Check if user already has perfect day badge
        let hasPerfectDayBadge = (profile.badges ?? []).contains { badge in
            badge.badge?.name == "Perfect Day"
        }
        
        if !hasPerfectDayBadge {
            if let perfectDayBadge = getPerfectDayBadge(context: context) {
                let userBadge = UserBadge(badge: perfectDayBadge, userProfile: profile)
                profile.badges?.append(userBadge)
                context.insert(userBadge)
                
                perfectDayBadge.award()
            }
        }
    }
    
    // MARK: - Notifications
    
    private func notifyAchievementUnlocked(_ userAchievement: UserAchievement) async {
        guard let achievement = userAchievement.achievement else { return }
        
        logger.info("Achievement unlocked: \(achievement.name)")
        
        // This would trigger a notification to the user
        // Implementation would depend on the notification system
    }
    
    // Timer for periodic updates - must be retained
    private var updateTimer: Timer?

    // MARK: - Periodic Updates

    private func setupPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performPeriodicUpdates()
            }
        }
    }

    /// Call this method to clean up resources when the manager is no longer needed
    func cleanup() {
        updateTimer?.invalidate()
        updateTimer = nil
        currentProfile = nil
        recentAchievements.removeAll()
        pendingRewards.removeAll()
    }
    
    private func performPeriodicUpdates() async {
        logger.info("Performing periodic gamification updates")
        
        // This would update leaderboards, check for expired challenges, etc.
        // Implementation would require access to model context
    }
    
    // MARK: - Helper Methods
    
    private func createDefaultAchievements(context: ModelContext) -> [Achievement] {
        let achievements = [
            // Productivity Achievements
            Achievement(
                name: "First Steps",
                description: "Complete your first reminder",
                category: .productivity,
                type: .milestone,
                difficulty: .easy
            ),
            Achievement(
                name: "Getting Started",
                description: "Complete 10 reminders",
                category: .productivity,
                type: .milestone,
                difficulty: .easy
            ),
            Achievement(
                name: "Productive",
                description: "Complete 50 reminders",
                category: .productivity,
                type: .milestone,
                difficulty: .medium
            ),
            Achievement(
                name: "Super Productive",
                description: "Complete 100 reminders",
                category: .productivity,
                type: .milestone,
                difficulty: .hard
            ),
            Achievement(
                name: "Productivity Master",
                description: "Complete 500 reminders",
                category: .productivity,
                type: .milestone,
                difficulty: .legendary
            ),
            
            // Habit Achievements
            Achievement(
                name: "Habit Starter",
                description: "Complete your first habit",
                category: .habits,
                type: .milestone,
                difficulty: .easy
            ),
            Achievement(
                name: "Habit Builder",
                description: "Complete 25 habits",
                category: .habits,
                type: .milestone,
                difficulty: .medium
            ),
            Achievement(
                name: "Habit Master",
                description: "Complete 100 habits",
                category: .habits,
                type: .milestone,
                difficulty: .hard
            ),
            
            // Focus Achievements
            Achievement(
                name: "First Focus",
                description: "Complete your first focus session",
                category: .focus,
                type: .milestone,
                difficulty: .easy
            ),
            Achievement(
                name: "Focus Enthusiast",
                description: "Complete 10 hours of focus time",
                category: .focus,
                type: .milestone,
                difficulty: .medium
            ),
            Achievement(
                name: "Focus Master",
                description: "Complete 50 hours of focus time",
                category: .focus,
                type: .milestone,
                difficulty: .hard
            ),
            Achievement(
                name: "Zen Master",
                description: "Complete 100 hours of focus time",
                category: .focus,
                type: .milestone,
                difficulty: .legendary
            ),
            
            // Streak Achievements
            Achievement(
                name: "Streak Starter",
                description: "Maintain a 3-day streak",
                category: .streaks,
                type: .streak,
                difficulty: .easy
            ),
            Achievement(
                name: "Week Warrior",
                description: "Maintain a 7-day streak",
                category: .streaks,
                type: .streak,
                difficulty: .medium
            ),
            Achievement(
                name: "Month Master",
                description: "Maintain a 30-day streak",
                category: .streaks,
                type: .streak,
                difficulty: .hard
            ),
            Achievement(
                name: "Legendary Streak",
                description: "Achieve a 100-day streak",
                category: .streaks,
                type: .streak,
                difficulty: .legendary
            ),
            
            // Milestone Achievements
            Achievement(
                name: "Level Up",
                description: "Reach level 5",
                category: .milestones,
                type: .milestone,
                difficulty: .easy
            ),
            Achievement(
                name: "Experienced",
                description: "Reach level 10",
                category: .milestones,
                type: .milestone,
                difficulty: .medium
            ),
            Achievement(
                name: "Expert",
                description: "Reach level 25",
                category: .milestones,
                type: .milestone,
                difficulty: .hard
            ),
            Achievement(
                name: "Master",
                description: "Reach level 50",
                category: .milestones,
                type: .milestone,
                difficulty: .legendary
            ),
            
            // Special Achievements
            Achievement(
                name: "Perfect Day",
                description: "Complete all planned tasks in a day",
                category: .special,
                type: .daily,
                difficulty: .medium
            )
        ]
        
        for achievement in achievements {
            context.insert(achievement)
        }
        
        return achievements
    }
    
    private func getPerfectDayBadge(context: ModelContext) -> Badge? {
        let descriptor = FetchDescriptor<Badge>(
            predicate: #Predicate { $0.name == "Perfect Day" }
        )
        
        return try? context.fetch(descriptor).first
    }
    
    // MARK: - Statistics
    
    func getGamificationStats(for profile: UserProfile) -> GamificationStats {
        return GamificationStats(
            level: profile.level,
            experience: profile.experience,
            totalExperience: profile.totalExperience,
            experienceToNextLevel: profile.experienceToNextLevel,
            progressToNextLevel: profile.progressToNextLevel,
            coins: profile.coins,
            gems: profile.gems,
            streak: profile.streak,
            longestStreak: profile.longestStreak,
            achievementsUnlocked: profile.achievementsUnlocked,
            totalAchievements: profile.achievements?.count ?? 0,
            badgesEarned: profile.badges?.count ?? 0,
            challengesCompleted: (profile.challenges ?? []).filter { $0.isCompleted }.count,
            activeChallenges: (profile.challenges ?? []).filter { !$0.isCompleted }.count,
            pendingRewards: (profile.rewards ?? []).filter { !$0.isCollected && !$0.isExpired }.count
        )
    }
}

// MARK: - Supporting Types

struct GamificationStats {
    let level: Int
    let experience: Int
    let totalExperience: Int
    let experienceToNextLevel: Int
    let progressToNextLevel: Double
    let coins: Int
    let gems: Int
    let streak: Int
    let longestStreak: Int
    let achievementsUnlocked: Int
    let totalAchievements: Int
    let badgesEarned: Int
    let challengesCompleted: Int
    let activeChallenges: Int
    let pendingRewards: Int
}

