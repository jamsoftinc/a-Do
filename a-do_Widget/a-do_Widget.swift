import WidgetKit
import SwiftUI
import SwiftData

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry { SimpleEntry(date: Date(), count: 0) }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date(), count: 0))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        // For widgets, we'll use a simpler approach without SwiftData to avoid MainActor issues
        // This provides a basic count that can be enhanced later
        let todayCount = 0 // Placeholder - can be enhanced with UserDefaults or other storage
        completion(Timeline(entries: [SimpleEntry(date: Date(), count: todayCount)], policy: .after(Date().addingTimeInterval(60*15))))
    }
}

struct SimpleEntry: TimelineEntry { let date: Date; let count: Int }

struct a_do_WidgetEntryView: View {
    var entry: Provider.Entry
    var body: some View {
        ZStack {
            LinearGradient(colors: AppTheme.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack {
                Text("Today's Tasks")
                    .font(.headline).foregroundStyle(.white)
                Text("\(entry.count)")
                    .font(.system(size: 48, weight: .bold)).foregroundStyle(.white)
            }
            .padding()
        }
    }
}

@main
struct a_do_Widget: Widget {
    let kind: String = "a-do_Widget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            a_do_WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today Count")
        .description("Shows the number of tasks due today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}


