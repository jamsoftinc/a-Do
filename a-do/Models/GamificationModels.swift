//
//  GamificationModels.swift
//  a-do
//
//  Gamification and achievement system models
//

import Foundation
import SwiftData

// MARK: - User Profile
@Model
final class UserProfile {
    var id: UUID = UUID()
    var userId: String = ""
    var displayName: String = ""
    var avatarURL: String?
    var level: Int = 1
    var experience: Int = 0
    var totalExperience: Int = 0
    var coins: Int = 0
    var gems: Int = 0
    var streak: Int = 0
    var longestStreak: Int = 0
    var lastActiveDate: Date = Date()
    var joinedDate: Date = Date()
    var title: String = "Beginner"
    var motto: String = ""
    var isPublic: Bool = false
    var preferences: Data? // JSON encoded preferences
    
    // Statistics
    var totalRemindersCompleted: Int = 0
    var totalHabitsCompleted: Int = 0
    var totalFocusTime: TimeInterval = 0
    var totalTimeTracked: TimeInterval = 0
    var perfectDays: Int = 0
    var achievementsUnlocked: Int = 0
    
    @Relationship(deleteRule: .cascade) var achievements: [UserAchievement]? = []
    @Relationship(deleteRule: .cascade) var badges: [UserBadge]? = []
    @Relationship(deleteRule: .cascade) var challenges: [UserChallenge]? = []
    @Relationship(deleteRule: .cascade) var rewards: [UserReward]? = []
    @Relationship(deleteRule: .cascade) var leaderboardEntries: [LeaderboardEntry]? = []
    
    init(userId: String, displayName: String) {
        self.userId = userId
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.joinedDate = Date()
        self.lastActiveDate = Date()
    }
    
    // MARK: - Experience and Leveling
    
    func addExperience(_ points: Int, reason: String = "") {
        experience += points
        totalExperience += points
        
        // Check for level up
        let newLevel = calculateLevel(from: totalExperience)
        if newLevel > level {
            levelUp(to: newLevel)
        }
        
        updateLastActive()
    }
    
    private func calculateLevel(from totalExp: Int) -> Int {
        // Level formula: level = floor(sqrt(totalExp / 100)) + 1
        return Int(sqrt(Double(totalExp) / 100.0)) + 1
    }
    
    private func experienceForLevel(_ level: Int) -> Int {
        // Experience needed for level: (level - 1)^2 * 100
        return (level - 1) * (level - 1) * 100
    }
    
    var experienceToNextLevel: Int {
        let nextLevel = level + 1
        let expForNextLevel = experienceForLevel(nextLevel)
        return expForNextLevel - totalExperience
    }
    
    var progressToNextLevel: Double {
        let currentLevelExp = experienceForLevel(level)
        let nextLevelExp = experienceForLevel(level + 1)
        let progressExp = totalExperience - currentLevelExp
        let totalNeeded = nextLevelExp - currentLevelExp
        
        return totalNeeded > 0 ? Double(progressExp) / Double(totalNeeded) : 0.0
    }
    
    private func levelUp(to newLevel: Int) {
        let oldLevel = level
        level = newLevel
        
        // Award level up rewards
        let coinsAwarded = newLevel * 10
        let gemsAwarded = newLevel >= 10 ? newLevel / 10 : 0
        
        addCoins(coinsAwarded)
        if gemsAwarded > 0 {
            addGems(gemsAwarded)
        }
        
        // Update title based on level
        updateTitle()
        
        // Create level up reward
        let reward = UserReward(
            type: .experience,
            title: "Level Up!",
            description: "Congratulations! You've reached level \(newLevel)!",
            coins: coinsAwarded,
            gems: gemsAwarded,
            userProfile: self
        )
        rewards?.append(reward)
    }
    
    private func updateTitle() {
        switch level {
        case 1..<5:
            title = "Beginner"
        case 5..<10:
            title = "Organizer"
        case 10..<20:
            title = "Achiever"
        case 20..<35:
            title = "Master"
        case 35..<50:
            title = "Expert"
        case 50..<75:
            title = "Legend"
        default:
            title = "Grandmaster"
        }
    }
    
    // MARK: - Currency Management
    
    func addCoins(_ amount: Int) {
        coins += amount
    }
    
    func spendCoins(_ amount: Int) -> Bool {
        guard coins >= amount else { return false }
        coins -= amount
        return true
    }
    
    func addGems(_ amount: Int) {
        gems += amount
    }
    
    func spendGems(_ amount: Int) -> Bool {
        guard gems >= amount else { return false }
        gems -= amount
        return true
    }
    
    // MARK: - Streak Management
    
    func updateStreak(completed: Bool) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastActive = calendar.startOfDay(for: lastActiveDate)
        
        if completed {
            if calendar.isDate(lastActive, inSameDayAs: today) {
                // Already active today, no change to streak
                return
            } else if calendar.dateInterval(of: .day, for: lastActive)?.end == calendar.dateInterval(of: .day, for: today)?.start {
                // Consecutive day
                streak += 1
                longestStreak = max(longestStreak, streak)
            } else {
                // Streak broken, start new
                streak = 1
            }
        } else {
            // Check if streak should be broken
            let daysSinceLastActive = calendar.dateComponents([.day], from: lastActive, to: today).day ?? 0
            if daysSinceLastActive > 1 {
                streak = 0
            }
        }
        
        updateLastActive()
    }
    
    private func updateLastActive() {
        lastActiveDate = Date()
    }
    
    // MARK: - Statistics Updates
    
    func recordReminderCompletion() {
        totalRemindersCompleted += 1
        addExperience(10, reason: "Completed reminder")
    }
    
    func recordHabitCompletion() {
        totalHabitsCompleted += 1
        addExperience(15, reason: "Completed habit")
    }
    
    func recordFocusTime(_ duration: TimeInterval) {
        totalFocusTime += duration
        let experiencePoints = Int(duration / 60) // 1 XP per minute
        addExperience(experiencePoints, reason: "Focus session")
    }
    
    func recordTimeTracking(_ duration: TimeInterval) {
        totalTimeTracked += duration
        let experiencePoints = Int(duration / 300) // 1 XP per 5 minutes
        addExperience(experiencePoints, reason: "Time tracking")
    }
    
    func recordPerfectDay() {
        perfectDays += 1
        addExperience(50, reason: "Perfect day")
        addCoins(25)
    }
}

// MARK: - Achievement
@Model
final class Achievement {
    var id: UUID = UUID()
    var name: String = ""
    var achievementDescription: String = ""
    var categoryRaw: String = AchievementCategory.productivity.rawValue
    var typeRaw: String = AchievementType.milestone.rawValue
    var difficultyRaw: String = AchievementDifficulty.easy.rawValue
    
    var category: AchievementCategory {
        get { AchievementCategory(rawValue: categoryRaw) ?? .productivity }
        set { categoryRaw = newValue.rawValue }
    }
    
    var type: AchievementType {
        get { AchievementType(rawValue: typeRaw) ?? .milestone }
        set { typeRaw = newValue.rawValue }
    }
    
    var difficulty: AchievementDifficulty {
        get { AchievementDifficulty(rawValue: difficultyRaw) ?? .easy }
        set { difficultyRaw = newValue.rawValue }
    }
    var icon: String = "trophy"
    var colorHex: String = "#FFD700"
    var experienceReward: Int = 0
    var coinReward: Int = 0
    var gemReward: Int = 0
    var isSecret: Bool = false
    var isActive: Bool = true
    var requirements: Data? // JSON encoded requirements
    var createdAt: Date = Date()
    var unlockedCount: Int = 0
    
    // Relationships
    @Relationship(deleteRule: .cascade) var userAchievements: [UserAchievement]? = []
    
    
    init(
        name: String,
        description: String,
        category: AchievementCategory,
        type: AchievementType = .milestone,
        difficulty: AchievementDifficulty = .easy
    ) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.achievementDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        self.categoryRaw = category.rawValue
        self.typeRaw = type.rawValue
        self.difficultyRaw = difficulty.rawValue
        self.experienceReward = difficulty.baseExperience
        self.coinReward = difficulty.baseCoins
        self.gemReward = difficulty.baseGems
        self.createdAt = Date()
    }
    
    func setRequirements<T: Codable>(_ requirements: T) {
        self.requirements = try? JSONEncoder().encode(requirements)
    }
    
    func getRequirements<T: Codable>(as type: T.Type) -> T? {
        guard let requirements = requirements else { return nil }
        return try? JSONDecoder().decode(type, from: requirements)
    }
    
    func unlock() {
        unlockedCount += 1
    }
    
    var rarity: AchievementRarity {
        switch unlockedCount {
        case 0: return .legendary
        case 1...10: return .epic
        case 11...50: return .rare
        case 51...200: return .uncommon
        default: return .common
        }
    }
}

// MARK: - Achievement Enums

enum AchievementCategory: String, CaseIterable, Codable {
    case productivity = "productivity"
    case habits = "habits"
    case focus = "focus"
    case social = "social"
    case streaks = "streaks"
    case milestones = "milestones"
    case special = "special"
    case seasonal = "seasonal"
    
    var displayName: String {
        switch self {
        case .productivity: return "Productivity"
        case .habits: return "Habits"
        case .focus: return "Focus"
        case .social: return "Social"
        case .streaks: return "Streaks"
        case .milestones: return "Milestones"
        case .special: return "Special"
        case .seasonal: return "Seasonal"
        }
    }
    
    var icon: String {
        switch self {
        case .productivity: return "chart.bar"
        case .habits: return "repeat"
        case .focus: return "target"
        case .social: return "person.2"
        case .streaks: return "flame"
        case .milestones: return "flag.checkered"
        case .special: return "star"
        case .seasonal: return "calendar"
        }
    }
}

enum AchievementType: String, CaseIterable, Codable {
    case milestone = "milestone"
    case streak = "streak"
    case challenge = "challenge"
    case social = "social"
    case hidden = "hidden"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .milestone: return "Milestone"
        case .streak: return "Streak"
        case .challenge: return "Challenge"
        case .social: return "Social"
        case .hidden: return "Hidden"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

enum AchievementDifficulty: String, CaseIterable, Codable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    case expert = "expert"
    case legendary = "legendary"
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .expert: return "Expert"
        case .legendary: return "Legendary"
        }
    }
    
    var baseExperience: Int {
        switch self {
        case .easy: return 25
        case .medium: return 50
        case .hard: return 100
        case .expert: return 200
        case .legendary: return 500
        }
    }
    
    var baseCoins: Int {
        switch self {
        case .easy: return 10
        case .medium: return 25
        case .hard: return 50
        case .expert: return 100
        case .legendary: return 250
        }
    }
    
    var baseGems: Int {
        switch self {
        case .easy: return 0
        case .medium: return 1
        case .hard: return 2
        case .expert: return 5
        case .legendary: return 10
        }
    }
    
    var color: String {
        switch self {
        case .easy: return "#34C759"
        case .medium: return "#007AFF"
        case .hard: return "#FF9500"
        case .expert: return "#FF3B30"
        case .legendary: return "#8E8E93"
        }
    }
}

enum AchievementRarity: String, CaseIterable, Codable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    
    var displayName: String {
        switch self {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }
    
    var color: String {
        switch self {
        case .common: return "#8E8E93"
        case .uncommon: return "#34C759"
        case .rare: return "#007AFF"
        case .epic: return "#8E8E93"
        case .legendary: return "#FFD700"
        }
    }
}

// MARK: - User Achievement
@Model
final class UserAchievement {
    var id: UUID = UUID()
    var achievementId: UUID = UUID()
    var unlockedAt: Date = Date()
    var progress: Double = 0.0
    var isCompleted: Bool = false
    var notificationSent: Bool = false
    
    @Relationship(deleteRule: .nullify) var achievement: Achievement?
    @Relationship(deleteRule: .nullify, inverse: \UserProfile.achievements) var userProfile: UserProfile?
    
    
    init(achievement: Achievement, userProfile: UserProfile) {
        self.achievementId = achievement.id
        self.achievement = achievement
        self.userProfile = userProfile
        self.unlockedAt = Date()
    }
    
    func updateProgress(_ newProgress: Double) {
        progress = min(1.0, max(0.0, newProgress))
        
        if progress >= 1.0 && !isCompleted {
            complete()
        }
    }
    
    func complete() {
        isCompleted = true
        progress = 1.0
        unlockedAt = Date()
        
        // Award rewards
        if let achievement = achievement, let profile = userProfile {
            profile.addExperience(achievement.experienceReward)
            profile.addCoins(achievement.coinReward)
            profile.addGems(achievement.gemReward)
            profile.achievementsUnlocked += 1
            
            achievement.unlock()
        }
    }
}

// MARK: - Badge
@Model
final class Badge {
    var id: UUID = UUID()
    var name: String = ""
    var badgeDescription: String = ""
    var icon: String = "shield"
    var colorHex: String = "#007AFF"
    var categoryRaw: String = BadgeCategory.achievement.rawValue
    var rarityRaw: String = BadgeRarity.common.rawValue
    
    var category: BadgeCategory {
        get { BadgeCategory(rawValue: categoryRaw) ?? .achievement }
        set { categoryRaw = newValue.rawValue }
    }
    
    var rarity: BadgeRarity {
        get { BadgeRarity(rawValue: rarityRaw) ?? .common }
        set { rarityRaw = newValue.rawValue }
    }
    var isActive: Bool = true
    var requirements: Data? // JSON encoded requirements
    var createdAt: Date = Date()
    var awardedCount: Int = 0
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \UserBadge.badge) var userBadges: [UserBadge]? = []
    
    
    init(name: String, description: String, category: BadgeCategory, rarity: BadgeRarity = .common) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.badgeDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        self.categoryRaw = category.rawValue
        self.rarityRaw = rarity.rawValue
        self.createdAt = Date()
    }
    
    func award() {
        awardedCount += 1
    }
}

// MARK: - Badge Enums

enum BadgeCategory: String, CaseIterable, Codable {
    case achievement = "achievement"
    case streak = "streak"
    case milestone = "milestone"
    case special = "special"
    case seasonal = "seasonal"
    case community = "community"
    
    var displayName: String {
        switch self {
        case .achievement: return "Achievement"
        case .streak: return "Streak"
        case .milestone: return "Milestone"
        case .special: return "Special"
        case .seasonal: return "Seasonal"
        case .community: return "Community"
        }
    }
}

enum BadgeRarity: String, CaseIterable, Codable {
    case common = "common"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    
    var displayName: String {
        switch self {
        case .common: return "Common"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }
}

// MARK: - User Badge
@Model
final class UserBadge {
    var id: UUID = UUID()
    var badgeId: UUID = UUID()
    var awardedAt: Date = Date()
    var isDisplayed: Bool = true
    var displayOrder: Int = 0
    
    @Relationship(deleteRule: .nullify) var badge: Badge?
    @Relationship(deleteRule: .nullify, inverse: \UserProfile.badges) var userProfile: UserProfile?
    
    
    init(badge: Badge, userProfile: UserProfile) {
        self.badgeId = badge.id
        self.badge = badge
        self.userProfile = userProfile
        self.awardedAt = Date()
        self.displayOrder = userProfile.badges?.count ?? 0
    }
}

// MARK: - Challenge
@Model
final class Challenge {
    var id: UUID = UUID()
    var name: String = ""
    var challengeDescription: String = ""
    var typeRaw: String = ChallengeType.daily.rawValue
    var categoryRaw: String = ChallengeCategory.productivity.rawValue
    var difficultyRaw: String = ChallengeDifficulty.easy.rawValue
    
    var type: ChallengeType {
        get { ChallengeType(rawValue: typeRaw) ?? .daily }
        set { typeRaw = newValue.rawValue }
    }
    
    var category: ChallengeCategory {
        get { ChallengeCategory(rawValue: categoryRaw) ?? .productivity }
        set { categoryRaw = newValue.rawValue }
    }
    
    var difficulty: ChallengeDifficulty {
        get { ChallengeDifficulty(rawValue: difficultyRaw) ?? .easy }
        set { difficultyRaw = newValue.rawValue }
    }
    var startDate: Date = Date()
    var endDate: Date = Date()
    var isActive: Bool = true
    var participantCount: Int = 0
    var completionCount: Int = 0
    var requirements: Data? // JSON encoded requirements
    var rewards: Data? // JSON encoded rewards
    var createdAt: Date = Date()
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \UserChallenge.challenge) var userChallenges: [UserChallenge]? = []
    
    
    init(
        name: String,
        description: String,
        type: ChallengeType,
        category: ChallengeCategory,
        difficulty: ChallengeDifficulty = .easy
    ) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.challengeDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        self.typeRaw = type.rawValue
        self.categoryRaw = category.rawValue
        self.difficultyRaw = difficulty.rawValue
        self.createdAt = Date()
        
        // Set default duration based on type
        let calendar = Calendar.current
        switch type {
        case .daily:
            endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        case .weekly:
            endDate = calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? startDate
        case .monthly:
            endDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case .custom:
            endDate = calendar.date(byAdding: .day, value: 7, to: startDate) ?? startDate
        }
    }
    
    var isExpired: Bool {
        return Date() > endDate
    }
    
    var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
    
    var completionRate: Double {
        guard participantCount > 0 else { return 0.0 }
        return Double(completionCount) / Double(participantCount)
    }
    
    func join() {
        participantCount += 1
    }
    
    func complete() {
        completionCount += 1
    }
}

// MARK: - Challenge Enums

enum ChallengeType: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .custom: return "Custom"
        }
    }
}

enum ChallengeCategory: String, CaseIterable, Codable {
    case productivity = "productivity"
    case habits = "habits"
    case focus = "focus"
    case health = "health"
    case learning = "learning"
    case social = "social"
    
    var displayName: String {
        switch self {
        case .productivity: return "Productivity"
        case .habits: return "Habits"
        case .focus: return "Focus"
        case .health: return "Health"
        case .learning: return "Learning"
        case .social: return "Social"
        }
    }
}

enum ChallengeDifficulty: String, CaseIterable, Codable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    case extreme = "extreme"
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .extreme: return "Extreme"
        }
    }
    
    var multiplier: Double {
        switch self {
        case .easy: return 1.0
        case .medium: return 1.5
        case .hard: return 2.0
        case .extreme: return 3.0
        }
    }
}

// MARK: - User Challenge
@Model
final class UserChallenge {
    var id: UUID = UUID()
    var challengeId: UUID = UUID()
    var joinedAt: Date = Date()
    var completedAt: Date?
    var progress: Double = 0.0
    var isCompleted: Bool = false
    var rank: Int = 0
    var score: Int = 0
    
    @Relationship(deleteRule: .nullify) var challenge: Challenge?
    @Relationship(deleteRule: .nullify) var userProfile: UserProfile?
    
    
    init(challenge: Challenge, userProfile: UserProfile) {
        self.challengeId = challenge.id
        self.challenge = challenge
        self.userProfile = userProfile
        self.joinedAt = Date()
    }
    
    func updateProgress(_ newProgress: Double) {
        progress = min(1.0, max(0.0, newProgress))
        
        if progress >= 1.0 && !isCompleted {
            complete()
        }
    }
    
    func complete() {
        isCompleted = true
        completedAt = Date()
        progress = 1.0
        
        challenge?.complete()
        
        // Award rewards based on challenge difficulty
        if let challenge = challenge, let profile = userProfile {
            let baseReward = 50
            let experienceReward = Int(Double(baseReward) * challenge.difficulty.multiplier)
            let coinReward = Int(Double(baseReward / 2) * challenge.difficulty.multiplier)
            
            profile.addExperience(experienceReward)
            profile.addCoins(coinReward)
        }
    }
}

// MARK: - Reward
@Model
final class Reward {
    var id: UUID = UUID()
    var name: String = ""
    var rewardDescription: String = ""
    var typeRaw: String = RewardType.experience.rawValue
    var categoryRaw: String = RewardCategory.achievement.rawValue
    var cost: Int = 0
    var currencyRaw: String = RewardCurrency.coins.rawValue
    
    var type: RewardType {
        get { RewardType(rawValue: typeRaw) ?? .experience }
        set { typeRaw = newValue.rawValue }
    }
    
    var category: RewardCategory {
        get { RewardCategory(rawValue: categoryRaw) ?? .achievement }
        set { categoryRaw = newValue.rawValue }
    }
    
    var currency: RewardCurrency {
        get { RewardCurrency(rawValue: currencyRaw) ?? .coins }
        set { currencyRaw = newValue.rawValue }
    }
    var icon: String = "gift"
    var colorHex: String = "#FFD700"
    var isActive: Bool = true
    var isLimitedTime: Bool = false
    var expirationDate: Date?
    var purchaseLimit: Int = 0
    var purchaseCount: Int = 0
    var createdAt: Date = Date()
    
    init(
        name: String,
        description: String,
        type: RewardType,
        category: RewardCategory,
        cost: Int,
        currency: RewardCurrency = .coins
    ) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rewardDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        self.typeRaw = type.rawValue
        self.categoryRaw = category.rawValue
        self.cost = cost
        self.currencyRaw = currency.rawValue
        self.createdAt = Date()
    }
    
    var isAvailable: Bool {
        guard isActive else { return false }
        
        if isLimitedTime, let expiration = expirationDate, Date() > expiration {
            return false
        }
        
        if purchaseLimit > 0 && purchaseCount >= purchaseLimit {
            return false
        }
        
        return true
    }
    
    func purchase() {
        purchaseCount += 1
    }
}

// MARK: - Reward Enums

enum RewardType: String, CaseIterable, Codable {
    case experience = "experience"
    case coins = "coins"
    case gems = "gems"
    case avatar = "avatar"
    case theme = "theme"
    case badge = "badge"
    case title = "title"
    case feature = "feature"
    
    var displayName: String {
        switch self {
        case .experience: return "Experience"
        case .coins: return "Coins"
        case .gems: return "Gems"
        case .avatar: return "Avatar"
        case .theme: return "Theme"
        case .badge: return "Badge"
        case .title: return "Title"
        case .feature: return "Feature"
        }
    }
}

enum RewardCategory: String, CaseIterable, Codable {
    case achievement = "achievement"
    case cosmetic = "cosmetic"
    case functional = "functional"
    case seasonal = "seasonal"
    case premium = "premium"
    
    var displayName: String {
        switch self {
        case .achievement: return "Achievement"
        case .cosmetic: return "Cosmetic"
        case .functional: return "Functional"
        case .seasonal: return "Seasonal"
        case .premium: return "Premium"
        }
    }
}

enum RewardCurrency: String, CaseIterable, Codable {
    case coins = "coins"
    case gems = "gems"
    case experience = "experience"
    
    var displayName: String {
        switch self {
        case .coins: return "Coins"
        case .gems: return "Gems"
        case .experience: return "Experience"
        }
    }
    
    var icon: String {
        switch self {
        case .coins: return "dollarsign.circle"
        case .gems: return "diamond"
        case .experience: return "star"
        }
    }
}

// MARK: - User Reward
@Model
final class UserReward {
    var id: UUID = UUID()
    var typeRaw: String = RewardType.experience.rawValue
    
    var type: RewardType {
        get { RewardType(rawValue: typeRaw) ?? .experience }
        set { typeRaw = newValue.rawValue }
    }
    var title: String = ""
    var rewardDescription: String = ""
    var coins: Int = 0
    var gems: Int = 0
    var experience: Int = 0
    var awardedAt: Date = Date()
    var isCollected: Bool = false
    var collectedAt: Date?
    var expirationDate: Date?
    
    @Relationship(deleteRule: .nullify) var userProfile: UserProfile?
    
    
    init(
        type: RewardType,
        title: String,
        description: String,
        coins: Int = 0,
        gems: Int = 0,
        experience: Int = 0,
        userProfile: UserProfile
    ) {
        self.typeRaw = type.rawValue
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rewardDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        self.coins = coins
        self.gems = gems
        self.experience = experience
        self.userProfile = userProfile
        self.awardedAt = Date()
        
        // Set expiration date (7 days from now)
        self.expirationDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
    }
    
    var isExpired: Bool {
        guard let expiration = expirationDate else { return false }
        return Date() > expiration
    }
    
    func collect() {
        guard !isCollected && !isExpired else { return }
        
        isCollected = true
        collectedAt = Date()
        
        // Award the rewards to user profile
        userProfile?.addCoins(coins)
        userProfile?.addGems(gems)
        userProfile?.addExperience(experience)
    }
}

// MARK: - Leaderboard
@Model
final class Leaderboard {
    var id: UUID = UUID()
    var name: String = ""
    var leaderboardDescription: String = ""
    var typeRaw: String = LeaderboardType.experience.rawValue
    var periodRaw: String = LeaderboardPeriod.weekly.rawValue
    
    var type: LeaderboardType {
        get { LeaderboardType(rawValue: typeRaw) ?? .experience }
        set { typeRaw = newValue.rawValue }
    }
    
    var period: LeaderboardPeriod {
        get { LeaderboardPeriod(rawValue: periodRaw) ?? .weekly }
        set { periodRaw = newValue.rawValue }
    }
    var isActive: Bool = true
    var startDate: Date = Date()
    var endDate: Date = Date()
    var participantCount: Int = 0
    var createdAt: Date = Date()
    
    @Relationship(deleteRule: .cascade) var entries: [LeaderboardEntry]? = []
    
    init(name: String, type: LeaderboardType, period: LeaderboardPeriod) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.typeRaw = type.rawValue
        self.periodRaw = period.rawValue
        self.createdAt = Date()
        
        // Set end date based on period
        let calendar = Calendar.current
        switch period {
        case .daily:
            endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        case .weekly:
            endDate = calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? startDate
        case .monthly:
            endDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case .allTime:
            endDate = calendar.date(byAdding: .year, value: 100, to: startDate) ?? startDate
        }
    }
    
    var isExpired: Bool {
        return Date() > endDate && period != .allTime
    }
    
    func addEntry(_ entry: LeaderboardEntry) {
        entries?.append(entry)
        participantCount = entries?.count ?? 0
        
        // Sort entries by score
        entries?.sort { $0.score > $1.score }
        
        // Update ranks
        for (index, entry) in (entries ?? []).enumerated() {
            entry.rank = index + 1
        }
    }
}

// MARK: - Leaderboard Enums

enum LeaderboardType: String, CaseIterable, Codable {
    case experience = "experience"
    case streaks = "streaks"
    case reminders = "reminders"
    case habits = "habits"
    case focusTime = "focus_time"
    case achievements = "achievements"
    
    var displayName: String {
        switch self {
        case .experience: return "Experience"
        case .streaks: return "Streaks"
        case .reminders: return "Reminders Completed"
        case .habits: return "Habits Completed"
        case .focusTime: return "Focus Time"
        case .achievements: return "Achievements"
        }
    }
}

enum LeaderboardPeriod: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case allTime = "all_time"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .allTime: return "All Time"
        }
    }
}

// MARK: - Leaderboard Entry
@Model
final class LeaderboardEntry {
    var id: UUID = UUID()
    var userId: String = ""
    var displayName: String = ""
    var score: Int = 0
    var rank: Int = 0
    var previousRank: Int = 0
    var lastUpdated: Date = Date()
    
    @Relationship(inverse: \Leaderboard.entries) var leaderboard: Leaderboard?
    @Relationship(deleteRule: .nullify) var userProfile: UserProfile?
    
    
    init(userId: String, displayName: String, score: Int, leaderboard: Leaderboard) {
        self.userId = userId
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.score = score
        self.leaderboard = leaderboard
        self.lastUpdated = Date()
    }
    
    func updateScore(_ newScore: Int) {
        previousRank = rank
        score = newScore
        lastUpdated = Date()
    }
    
    var rankChange: Int {
        return previousRank - rank
    }
    
    var isRankImproved: Bool {
        return rankChange > 0
    }
}
