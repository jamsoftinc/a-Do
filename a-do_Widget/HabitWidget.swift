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
        HabitEntry(date: Date(), habits: [
            HabitData(title: "Exercise", icon: "figure.run", color: "#007AFF", currentStreak: 5, isCompletedToday: true),
            HabitData(title: "Read", icon: "book.fill", color: "#34C759", currentStreak: 3, isCompletedToday: false)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitEntry) -> ()) {
        let entry = HabitEntry(date: Date(), habits: [
            HabitData(title: "Exercise", icon: "figure.run", color: "#007AFF", currentStreak: 5, isCompletedToday: true),
            HabitData(title: "Read", icon: "book.fill", color: "#34C759", currentStreak: 3, isCompletedToday: false)
        ])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitEntry>) -> ()) {
        let currentDate = Date()

        // Check Pro status
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.ado.app"),
              sharedDefaults.bool(forKey: "isProUser") else {
            // Show upgrade message for free users
            let entry = HabitEntry(date: currentDate, habits: [
                HabitData(title: "Widgets are a Pro feature", icon: "star.fill", color: "#FF9500", currentStreak: 0, isCompletedToday: false)
            ])
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
            return
        }

        // For now, return a simple timeline that updates every hour
        let entry = HabitEntry(date: currentDate, habits: [
            HabitData(title: "Exercise", icon: "figure.run", color: "#007AFF", currentStreak: 5, isCompletedToday: true),
            HabitData(title: "Read", icon: "book.fill", color: "#34C759", currentStreak: 3, isCompletedToday: false)
        ])

        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct HabitEntry: TimelineEntry {
    let date: Date
    let habits: [HabitData]
}

struct HabitData {
    let title: String
    let icon: String
    let color: String
    let currentStreak: Int
    let isCompletedToday: Bool
}

struct HabitWidgetEntryView: View {
    var entry: HabitProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                Text("Habits")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            if entry.habits.isEmpty {
                VStack {
                    Image(systemName: "star.circle")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No habits yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(Array(entry.habits.prefix(3).enumerated()), id: \.offset) { index, habit in
                    HabitRowView(habit: habit)
                }

                if entry.habits.count > 3 {
                    Text("+\(entry.habits.count - 3) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

struct HabitRowView: View {
    let habit: HabitData

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: habit.icon)
                .foregroundColor(Color(hex: habit.color) ?? .blue)
                .frame(width: 16, height: 16)

            Text(habit.title)
                .font(.caption)
                .lineLimit(1)
                .strikethrough(habit.isCompletedToday)
                .foregroundColor(habit.isCompletedToday ? .secondary : .primary)

            Spacer()

            // Interactive completion button
            Button(intent: CompleteHabitIntent(habitId: habit.id)) {
                Image(systemName: habit.isCompletedToday ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(habit.isCompletedToday ? .green : .gray)
                    .font(.body)
            }
            .buttonStyle(.plain)
        }
    }
}

// Add HabitData update to include id
extension HabitData {
    var id: String {
        return title // For now, use title as ID; should be UUID in production
    }
}

// Color extension for hex colors
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

#Preview(as: .systemSmall) {
    HabitWidget()
} timeline: {
    HabitEntry(date: .now, habits: [
        HabitData(title: "Exercise", icon: "figure.run", color: "#007AFF", currentStreak: 5, isCompletedToday: true),
        HabitData(title: "Read", icon: "book.fill", color: "#34C759", currentStreak: 3, isCompletedToday: false)
    ])
}

#Preview(as: .systemMedium) {
    HabitWidget()
} timeline: {
    HabitEntry(date: .now, habits: [
        HabitData(title: "Exercise", icon: "figure.run", color: "#007AFF", currentStreak: 5, isCompletedToday: true),
        HabitData(title: "Read", icon: "book.fill", color: "#34C759", currentStreak: 3, isCompletedToday: false),
        HabitData(title: "Meditate", icon: "brain.head.profile", color: "#FF9500", currentStreak: 7, isCompletedToday: true)
    ])
}
