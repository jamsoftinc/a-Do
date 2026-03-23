import SwiftUI

struct DayStripView: View {
    @Binding var selectedDate: Date
    private let calendar = Calendar.current

    private var weekDates: [Date] {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekDates, id: \.self) { date in
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isToday = calendar.isDateInToday(date)

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedDate = date
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : AppTheme.Colors.textSecondary)

                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(.body, design: .rounded).weight(.bold))
                            .foregroundStyle(isSelected ? .white : AppTheme.Colors.textPrimary)

                        if isToday && isSelected {
                            Circle()
                                .fill(.white)
                                .frame(width: 5, height: 5)
                        } else if isToday {
                            Circle()
                                .fill(AppTheme.Colors.primary)
                                .frame(width: 5, height: 5)
                        } else {
                            Circle()
                                .fill(.clear)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
                            .fill(isSelected ? AppTheme.Colors.primary : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }
}
