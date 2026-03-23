import SwiftUI
import SwiftData
import Charts

struct InsightsHabitsView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(filter: #Predicate<Habit> { $0.isActive }) private var activeHabits: [Habit]

    @State private var showingSettings = false
    @State private var showingReminderForm = false
    @State private var showingAllHabits = false
    @State private var showingPaywall = false

    private var gamificationManager = GamificationManager.shared

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                    weeklyInsightCard
                    gamificationCard
                    productivityTrendsCard
                    activeHabitsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { profileAvatar }
                }
                ToolbarItem(placement: .principal) {
                    Text("A-do")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingReminderForm = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.Colors.primary, in: Circle())
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack { SettingsPageView() }
            }
            .sheet(isPresented: $showingReminderForm) {
                NavigationStack { ReminderFormView() }
            }
            .sheet(isPresented: $showingAllHabits) {
                NavigationStack { HabitsView() }
            }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
        }
    }

    // MARK: - Profile Avatar

    private var profileAvatar: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.primary.opacity(0.14))
                .frame(width: 34, height: 34)
            if let name = profiles.first?.displayName, !name.isEmpty {
                Text(String(name.prefix(1)).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primary)
            } else {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.primary)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("GROWTH JOURNEY")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .tracking(1.0)

            HStack(spacing: 0) {
                Text("Insights &\n")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                +
                Text("Habits.")
                    .font(.system(size: 28, weight: .bold).italic())
                    .foregroundStyle(AppTheme.Colors.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Weekly Insight

    private var weeklyInsightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                Text("WEEKLY INSIGHT")
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
            }
            .foregroundStyle(AppTheme.Colors.primary)

            Text(weeklyInsightText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { _ in
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.3))
                        .frame(width: 24, height: 24)
                }

                Text("Based on your last 7 days of activity.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xl, style: .continuous)
                .fill(AppTheme.Colors.primary.opacity(0.08))
        )
    }

    private var weeklyInsightText: String {
        if activeHabits.isEmpty {
            return "Start building habits to unlock personalized insights about your productivity patterns."
        }
        let completedToday = activeHabits.filter { habit in
            let todayEntries = habit.entries?.filter { Calendar.current.isDateInToday($0.date) } ?? []
            let total = todayEntries.reduce(0.0) { $0 + Double($1.count) }
            return total >= Double(habit.targetCount) && Double(habit.targetCount) > 0
        }.count

        if completedToday > 0 {
            return "You're \(Int((Double(completedToday) / Double(activeHabits.count)) * 100))% more focused when you start your day with meditation."
        }
        return "Keep building your streak. Consistency compounds over time."
    }

    // MARK: - Gamification

    private var gamificationCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.9))

            Text("Steady Flow")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("You've completed \(completedTodayCount) tasks today. Keep the momentum going!")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            Text("LEVEL \(currentLevel) ACHIEVED")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.white.opacity(0.2), in: Capsule())
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.Colors.primary, AppTheme.Colors.primaryLight.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var completedTodayCount: Int {
        activeHabits.filter { habit in
            let todayEntries = habit.entries?.filter { Calendar.current.isDateInToday($0.date) } ?? []
            let total = todayEntries.reduce(0.0) { $0 + Double($1.count) }
            return total >= Double(habit.targetCount) && Double(habit.targetCount) > 0
        }.count
    }

    private var currentLevel: Int {
        max(1, completedTodayCount + 1)
    }

    // MARK: - Productivity Trends

    private var productivityTrendsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Productivity Trends")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        Text("Weekly focus duration")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(String(format: "%.1f", weeklyFocusHours))h")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.Colors.primary)

                        Text("+12% VS LAST WEEK")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.success)
                    }
                }

                weeklyBarChart
            }
        }
    }

    private var weeklyFocusHours: Double {
        34.2 // Placeholder - would come from TimeTrackingManager
    }

    private var weeklyBarChart: some View {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let values: [Double] = [4.5, 5.2, 6.1, 4.8, 7.2, 3.4, 3.0]
        let today = Calendar.current.component(.weekday, from: Date())
        let todayIndex = (today + 5) % 7 // Convert Sunday=1 to Mon=0 index

        return Chart {
            ForEach(Array(zip(days.indices, days)), id: \.0) { index, day in
                BarMark(
                    x: .value("Day", day),
                    y: .value("Hours", values[index])
                )
                .foregroundStyle(index == todayIndex ? AppTheme.Colors.primary : AppTheme.Colors.primary.opacity(0.3))
                .cornerRadius(4)
            }
        }
        .frame(height: 120)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisValueLabel()
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
        }
    }

    // MARK: - Active Habits

    private var activeHabitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Habits")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Spacer()

                Button("VIEW ALL") {
                    showingAllHabits = true
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primary)
            }

            if activeHabits.isEmpty {
                GlassCard {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "flame")
                                .font(.title2)
                                .foregroundStyle(AppTheme.Colors.secondary)
                            Text("No active habits")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(activeHabits, id: \.id) { habit in
                        habitCard(habit: habit)
                    }
                }
            }
        }
    }

    private func habitCard(habit: Habit) -> some View {
        let todayEntries = habit.entries?.filter { Calendar.current.isDateInToday($0.date) } ?? []
        let todayValue = todayEntries.reduce(0.0) { $0 + Double($1.count) }
        let isCompleted = todayValue >= Double(habit.targetCount) && Double(habit.targetCount) > 0
        let streak = habit.currentStreak

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(habitColor(for: habit).opacity(0.14))
                    .frame(width: 44, height: 44)

                Image(systemName: habit.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(habitColor(for: habit))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                if !habit.unit.isEmpty {
                    Text("\(habit.targetCount) \(habit.unit) daily")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            Spacer()

            if isCompleted {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(streak)")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.Colors.success)
                    Text("DAY STREAK")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.success)
                }
            } else if todayValue == 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("0")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.Colors.error)
                    Text("MISSED TODAY")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.error)
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(streak)")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primary)
                    Text("DAY STREAK")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }

    private func habitColor(for habit: Habit) -> Color {
        Color(hex: habit.color) ?? AppTheme.Colors.primary
    }
}
