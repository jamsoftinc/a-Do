import WidgetKit
import SwiftUI
import SwiftData

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry { SimpleEntry(date: Date(), count: 3) }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date(), count: 3))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let container = AppContainer.container
        let modelContext = ModelContext(container)
        let desc = FetchDescriptor<Reminder>()
        let reminders = (try? modelContext.fetch(desc)) ?? []
        let todayCount = reminders.filter { rem in
            if let due = rem.dueDate { return Calendar.current.isDateInToday(due) && !rem.isCompleted }
            return false
        }.count
        completion(Timeline(entries: [SimpleEntry(date: Date(), count: todayCount)], policy: .after(Date().addingTimeInterval(60*15))))
    }
}

struct SimpleEntry: TimelineEntry { let date: Date; let count: Int }

struct Remember_WidgetEntryView: View {
    var entry: Provider.Entry
    var body: some View {
        ZStack {
            LinearGradient(colors: AppTheme.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack {
                Text("Today's Reminders")
                    .font(.headline).foregroundStyle(.white)
                Text("\(entry.count)")
                    .font(.system(size: 48, weight: .bold)).foregroundStyle(.white)
            }
            .padding()
        }
    }
}

@main
struct Remember_Widget: Widget {
    let kind: String = "Remember_Widget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            Remember_WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today Count")
        .description("Shows the number of reminders due today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}


