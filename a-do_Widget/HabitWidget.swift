//
//  HabitWidget.swift
//  a-do_Widget
//
//  Created by Ahmad Hamilton on 8/10/25.
//

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - App Colors (Copied from AppTheme to avoid target membership issues)
struct WidgetTheme {
    static let primary = Color(red: 0.4, green: 0.2, blue: 0.8)
    static let primaryLight = Color(red: 0.5, green: 0.3, blue: 0.9)
    static let secondary = Color(red: 0.9, green: 0.4, blue: 0.6)
    static let accent = Color(red: 0.2, green: 0.8, blue: 0.6)
    
    static let success = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let warning = Color(red: 0.9, green: 0.6, blue: 0.2)
    static let error = Color(red: 0.9, green: 0.3, blue: 0.3)
    
    static let high = Color(red: 0.9, green: 0.3, blue: 0.3)
    static let medium = Color(red: 0.9, green: 0.6, blue: 0.2)
    static let low = Color(red: 0.2, green: 0.8, blue: 0.4)
}

struct HabitWidget: Widget {
    let kind: String = "HabitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitProvider()) { entry in
            HabitWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Habit Tracker")
        .description("Track your daily habits and see your progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HabitProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitEntry {
        HabitEntry(date: Date(), habits: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitEntry) -> ()) {
        let entry = HabitEntry(date: Date(), habits: fetchHabits())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitEntry>) -> ()) {
        let currentDate = Date()

        // Check Pro status
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.ado.app"),
              sharedDefaults.bool(forKey: "isProUser") else {
            // Show upgrade message for free users
            let entry = HabitEntry(date: currentDate, habits: [
                HabitData(id: "upgrade", title: "Widgets are a Pro feature", icon: "star.fill", color: "#FF9500", currentStreak: 0, isCompletedToday: false)
            ])
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }

        let entry = HabitEntry(date: currentDate, habits: fetchHabits())

        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchHabits() -> [HabitData] {
        guard
            let defaults = UserDefaults(suiteName: "group.com.ado.app"),
            let rawData = defaults.data(forKey: "widget_habits_v1")
        else {
            return fallbackHabits()
        }

        do {
            let snapshots = try JSONDecoder().decode([HabitSnapshot].self, from: rawData)
            let mapped = snapshots.map { snapshot in
                HabitData(
                    id: snapshot.id,
                    title: snapshot.title,
                    icon: snapshot.icon,
                    color: snapshot.color,
                    currentStreak: snapshot.currentStreak,
                    isCompletedToday: snapshot.isCompletedToday
                )
            }
            return mapped.isEmpty ? fallbackHabits() : mapped
        } catch {
            return fallbackHabits()
        }
    }

    private func fallbackHabits() -> [HabitData] {
        []
    }
}

struct HabitEntry: TimelineEntry {
    let date: Date
    let habits: [HabitData]
}

struct HabitData {
    let id: String
    let title: String
    let icon: String
    let color: String
    let currentStreak: Int
    let isCompletedToday: Bool
}

private struct HabitSnapshot: Codable {
    let id: String
    let title: String
    let icon: String
    let color: String
    let currentStreak: Int
    let isCompletedToday: Bool
}

struct HabitWidgetEntryView: View {
    var entry: HabitProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(title: "Habits", icon: "star.fill", color: WidgetTheme.primary)

            if entry.habits.isEmpty {
                EmptyWidgetView(message: "No habits yet", icon: "star")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(entry.habits.prefix(3).enumerated()), id: \.offset) { index, habit in
                        HabitRowView(habit: habit)
                    }
                }

                if entry.habits.count > 3 {
                    Text("+\(entry.habits.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 28) // Align with text in row
                }
            }
        }
    }
}

struct HabitRowView: View {
    let habit: HabitData

    var body: some View {
        HStack(spacing: 12) {
            // Interactive completion button
            Button(intent: CompleteHabitIntent(habitId: habit.id)) {
                ZStack {
                    Circle()
                        .fill(habit.isCompletedToday ? (Color(hex: habit.color) ?? .blue).opacity(0.15) : .clear)
                        .overlay(
                            Circle()
                                .strokeBorder(habit.isCompletedToday ? (Color(hex: habit.color) ?? .blue) : Color.secondary.opacity(0.3), lineWidth: 1.5)
                        )
                    
                    if habit.isCompletedToday {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: habit.color) ?? .blue)
                    }
                }
                .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(habit.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(habit.isCompletedToday ? .secondary : .primary)
                    .strikethrough(habit.isCompletedToday)

                if habit.currentStreak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8))
                        Text("\(habit.currentStreak) day streak")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(WidgetTheme.secondary)
                }
            }

            Spacer()
            
            Image(systemName: habit.icon)
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: habit.color) ?? .blue)
                .opacity(habit.isCompletedToday ? 0.5 : 1)
        }
        .widgetCardStyle()
    }
}

// MARK: - Color extension for hex colors
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

struct HabitWidgetPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            HabitWidgetEntryView(
                entry: HabitEntry(
                    date: .now,
                    habits: []
                )
            )
            .previewContext(WidgetPreviewContext(family: .systemSmall))

            HabitWidgetEntryView(
                entry: HabitEntry(
                    date: .now,
                    habits: []
                )
            )
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}

// MARK: - Shared UI Components

struct WidgetHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
                .font(.system(size: 14, weight: .semibold))
            
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1)
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

struct EmptyWidgetView: View {
    let message: String
    let icon: String
    var color: Color = .secondary
    
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 32))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
            
            Text(message)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WidgetActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let intent: any AppIntent
    
    var body: some View {
        Button(intent: intent) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.gradient)
            )
            .shadow(color: color.opacity(0.3), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct WidgetCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.fill.quaternary)
                    .opacity(0.5)
            )
    }
}

extension View {
    func widgetCardStyle() -> some View {
        modifier(WidgetCardBackground())
    }
}
