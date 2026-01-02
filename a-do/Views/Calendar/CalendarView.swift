import SwiftUI
import EventKit

struct CalendarView: View {
    @State private var calendarManager = CalendarManager.shared
    @State private var currentDate = Date()
    @State private var selectedDate: Date?
    @State private var viewMode: ViewMode = .month
    
    enum ViewMode: String, CaseIterable {
        case month = "Month"
        case list = "List"
        case quantum = "Quantum"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View Mode Picker
                Picker("View Mode", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if viewMode == .month {
                    monthView
                } else if viewMode == .list {
                    listView
                } else {
                    if EntitlementManager.shared.isProUser {
                        QuantumCalendarView()
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "lock.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(AppTheme.Colors.primary)
                            
                            Text("Quantum Calendar")
                                .font(.title2.bold())
                            
                            Text("Upgrade to Pro to unlock visual time-blocking and AI execution slots.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            Button {
                                // SubscriptionManager.shared.showPaywall()
                            } label: {
                                Text("Upgrade to Pro")
                                    .bold()
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.Colors.primary)
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.Gradients.background.ignoresSafeArea())
                    }
                }
            }
            .navigationTitle("Calendar")
            .task {
                await calendarManager.requestAccess()
            }
        }
    }
    
    // MARK: - Month View
    private var monthView: some View {
        VStack(spacing: 0) {
            // Month Navigation
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundStyle(AppTheme.Colors.primary)
                }

                Spacer()

                Text(monthYearString)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundStyle(AppTheme.Colors.primary)
                }

                Button {
                    currentDate = Date()
                    selectedDate = Date()
                } label: {
                    Text("Today")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Weekday Headers
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Calendar Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(generateCalendarDays(), id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            events: eventsForDate(date),
                            isSelected: selectedDate != nil && Calendar.current.isDate(date, inSameDayAs: selectedDate!),
                            isToday: Calendar.current.isDateInToday(date),
                            isCurrentMonth: Calendar.current.isDate(date, equalTo: currentDate, toGranularity: .month)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
            .padding(.horizontal)

            Divider()
                .padding(.vertical, 12)

            // Selected Date Events Section - Always visible
            selectedDateEventsSection
        }
        .background(AppTheme.Gradients.background.ignoresSafeArea())
        .onAppear {
            // Auto-select today if no date selected
            if selectedDate == nil {
                selectedDate = Date()
            }
        }
    }

    // MARK: - Selected Date Events Section
    private var selectedDateEventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with selected date
            HStack {
                Text(selectedDateHeaderText)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Spacer()

                if let date = selectedDate {
                    Text(date, format: .dateTime.weekday(.wide))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .padding(.horizontal)

            // Events list
            let events = selectedDate.map { eventsForDate($0) } ?? []

            if events.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.Colors.textTertiary)

                    Text("No events")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(events, id: \.eventIdentifier) { event in
                            EventRow(event: event)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var selectedDateHeaderText: String {
        guard let date = selectedDate else { return "Select a date" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            return date.formatted(.dateTime.month().day())
        }
    }
    
    // MARK: - List View
    private var listView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Today's Events
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if calendarManager.todayEvents.isEmpty {
                        Text("No events today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(calendarManager.todayEvents, id: \.eventIdentifier) { event in
                                EventRow(event: event)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Upcoming Events
                VStack(alignment: .leading, spacing: 12) {
                    Text("Upcoming")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if calendarManager.upcomingEvents.isEmpty {
                        Text("No upcoming events")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(calendarManager.upcomingEvents, id: \.eventIdentifier) { event in
                                EventRow(event: event)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(AppTheme.Gradients.background.ignoresSafeArea())
        .refreshable {
            await calendarManager.loadEvents()
        }
    }
    
    // MARK: - Helper Methods
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentDate)
    }
    
    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        return formatter.veryShortWeekdaySymbols
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: currentDate) {
            currentDate = newDate
        }
    }
    
    private func generateCalendarDays() -> [Date?] {
        var days: [Date?] = []
        let calendar = Calendar.current
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return days
        }
        
        let startDate = monthFirstWeek.start
        
        for offset in 0..<42 { // 6 weeks max
            if let date = calendar.date(byAdding: .day, value: offset, to: startDate) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func eventsForDate(_ date: Date) -> [EKEvent] {
        let calendar = Calendar.current
        let allEvents = calendarManager.todayEvents + calendarManager.upcomingEvents
        return allEvents.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: date)
        }
    }
}

// MARK: - Day Cell
struct DayCell: View {
    let date: Date
    let events: [EKEvent]
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                .foregroundStyle(textColor)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(backgroundColor)
                )

            if !events.isEmpty {
                HStack(spacing: 2) {
                    ForEach(0..<min(events.count, 3), id: \.self) { index in
                        Circle()
                            .fill(Color(cgColor: events[index].calendar.cgColor))
                            .frame(width: 4, height: 4)
                    }
                }
            } else {
                // Spacer to maintain consistent height
                Color.clear.frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? AppTheme.Colors.primary.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? AppTheme.Colors.primary : Color.clear, lineWidth: 2)
        )
    }
    
    private var textColor: Color {
        if isToday {
            return .white
        } else if !isCurrentMonth {
            return AppTheme.Colors.textTertiary
        } else {
            return AppTheme.Colors.textPrimary
        }
    }
    
    private var backgroundColor: Color {
        if isToday {
            return AppTheme.Colors.primary
        } else {
            return .clear
        }
    }
}

// MARK: - Event Row
struct EventRow: View {
    let event: EKEvent
    
    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                // Time strip
                VStack(alignment: .center, spacing: 2) {
                    Text(event.startDate, style: .time)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.Colors.primary)
                    
                    Rectangle()
                        .fill(Color(cgColor: event.calendar.cgColor))
                        .frame(width: 3, height: 20)
                    
                    Text(event.endDate, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 50)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .primaryText()
                        .lineLimit(1)
                    
                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(location)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .secondaryText()
                    }
                }
                
                Spacer()
                
                Button {
                    CalendarManager.shared.openEventInCalendar(event)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
    }
}
