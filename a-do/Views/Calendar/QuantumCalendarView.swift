//
//  QuantumCalendarView.swift
//  a-do
//
//  Created for iOS 26+ Quantum Calendar Feature
//

import SwiftUI
import EventKit

struct QuantumCalendarView: View {
    @State private var calendarManager = CalendarManager.shared
    
    // Grid Configuration
    private let hours = Array(6...22) // 6 AM to 10 PM
    private let columns = [GridItem(.flexible())]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header / Legend
                HStack(spacing: 16) {
                    Label("Deep Focus", systemImage: "sparkles")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(Color.yellow.opacity(0.3))
                                .stroke(Color.yellow, lineWidth: 1)
                        )
                    
                    Label("Busy", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)
                
                // Heatmap Grid
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(hours, id: \.self) { hour in
                        QuantumHourRow(hour: hour, events: eventsForHour(hour))
                    }
                }
                .padding()
            }
        }
        .background(AppTheme.Gradients.background.ignoresSafeArea())
    }
    
    private func eventsForHour(_ hour: Int) -> [EKEvent] {
        let calendar = Calendar.current
        let events = calendarManager.todayEvents
        
        return events.filter { event in
            let hourComponent = calendar.component(.hour, from: event.startDate)
            return hourComponent == hour
        }
    }
}

struct QuantumHourRow: View {
    let hour: Int
    let events: [EKEvent]
    
    // Sub-blocks per hour (4 x 15 mins)
    private let blocks = 4
    
    var body: some View {
        HStack(spacing: 12) {
            // Time Label
            Text(timeString)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 45, alignment: .trailing)
            
            // Heatmap Bar
            HStack(spacing: 2) {
                ForEach(0..<blocks, id: \.self) { index in
                    // Determine intensity/type for this 15-min block
                    let status = blockStatus(for: index)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color(for: status))
                        .overlay(
                            status == .focus ? 
                            RoundedRectangle(cornerRadius: 4).stroke(Color.yellow, lineWidth: 1) : nil
                        )
                        .shadow(color: status == .focus ? .yellow.opacity(0.5) : .clear, radius: 4)
                        .frame(height: 30)
                }
            }
        }
    }
    
    private var timeString: String {
        return String(format: "%02d:00", hour)
    }
    
    enum BlockStatus {
        case empty
        case busy
        case focus
    }
    
    // Simulate Logic for "Quantum" Prediction
    // In production, this would call a real AI/Algorithm
    private func blockStatus(for index: Int) -> BlockStatus {
        // If we have actual events overlapping this block
        if !events.isEmpty {
            return .busy
        }
        
        // Simulation: 9 AM - 11 AM are "Focus" slots
        if (hour >= 9 && hour <= 11) {
            return .focus
        }
        
        return .empty
    }
    
    private func color(for status: BlockStatus) -> Color {
        switch status {
        case .empty:
            return Color.white.opacity(0.05)
        case .busy:
            return AppTheme.Colors.primary.opacity(0.6)
        case .focus:
            return Color.yellow.opacity(0.3)
        }
    }
}
