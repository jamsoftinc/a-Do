//
//  TemplatesView.swift
//  a-do
//
//  Templates and recurring reminders interface
//

import SwiftUI
import SwiftData

struct TemplatesView: View {
    @Environment(\.modelContext) private var context
    @State private var recurringManager = RecurringRemindersManager.shared
    
    @State private var templates: [ReminderTemplate] = []
    @State private var recurringReminders: [RecurringReminder] = []
    
    @State private var selectedTab = 0
    @State private var showingCreateTemplate = false
    @State private var showingCreateRecurring = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("View", selection: $selectedTab) {
                    Text("Templates").tag(0)
                    Text("Recurring").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                TabView(selection: $selectedTab) {
                    templatesTab
                        .tag(0)
                    
                    recurringTab
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Templates & Recurring")
            .searchable(text: $searchText, prompt: "Search templates...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if selectedTab == 0 {
                            showingCreateTemplate = true
                        } else {
                            showingCreateRecurring = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateTemplate) {
            // TODO: Implement CreateTemplateView
            Text("Create Template View - Coming Soon")
                .navigationTitle("Create Template")
                .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingCreateRecurring) {
            // TODO: Implement CreateRecurringReminderView
            Text("Create Recurring Reminder View - Coming Soon")
                .navigationTitle("Create Recurring")
                .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            recurringManager.ensureDefaultTemplates(context: context)
        }
    }
    
    // MARK: - Templates Tab
    
    private var templatesTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Quick Actions
                quickTemplatesSection
                
                // Categories
                templateCategoriesSection
                
                // All Templates
                allTemplatesSection
            }
            .padding()
        }
    }
    
    private var quickTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Templates")
                .font(AppTheme.Typography.headline)
                .primaryText()
            
            let popularTemplates = recurringManager.getPopularTemplates(context: context, limit: 6)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(popularTemplates, id: \.id) { template in
                    QuickTemplateCard(template: template)
                }
            }
        }
    }
    
    private var templateCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories")
                .font(AppTheme.Typography.headline)
                .primaryText()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ReminderTemplate.defaultCategories, id: \.self) { category in
                        CategoryChip(category: category)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var allTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Templates")
                .font(AppTheme.Typography.headline)
                .primaryText()
            
            let filteredTemplates = searchText.isEmpty ? templates : 
                recurringManager.searchTemplates(query: searchText, context: context)
            
            LazyVStack(spacing: 8) {
                ForEach(filteredTemplates, id: \.id) { template in
                    TemplateRow(template: template)
                }
            }
        }
    }
    
    // MARK: - Recurring Tab
    
    private var recurringTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Stats Card
                recurringStatsCard
                
                // Active Recurring Reminders
                activeRecurringSection
                
                // Upcoming Reminders
                upcomingSection
            }
            .padding()
        }
    }
    
    private var recurringStatsCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                Text("Recurring Reminders")
                    .font(AppTheme.Typography.headline)
                    .primaryText()
                
                let stats = recurringManager.getRecurringReminderStats(context: context)
                
                HStack(spacing: 20) {
                    StatItem(title: "Active", value: "\(stats.totalRecurringReminders)")
                    StatItem(title: "Generated", value: "\(stats.totalGeneratedReminders)")
                    StatItem(title: "Upcoming", value: "\(stats.upcomingRecurring)")
                }
            }
        }
    }
    
    private var activeRecurringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Recurring")
                .font(AppTheme.Typography.headline)
                .primaryText()
            
            let activeRecurring = recurringReminders.filter { $0.isActive }
            
            if activeRecurring.isEmpty {
                EmptyStateView(
                    icon: "repeat",
                    title: "No Recurring Reminders",
                    subtitle: "Create recurring reminders to automate your routine tasks"
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(activeRecurring, id: \.id) { recurring in
                        RecurringReminderRow(recurringReminder: recurring)
                    }
                }
            }
        }
    }
    
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next 7 Days")
                .font(AppTheme.Typography.headline)
                .primaryText()
            
            let upcomingReminders = getUpcomingRecurringReminders()
            
            if upcomingReminders.isEmpty {
                Text("No upcoming recurring reminders")
                    .font(AppTheme.Typography.caption1)
                    .secondaryText()
                    .padding(.vertical)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(upcomingReminders, id: \.recurring.id) { item in
                        UpcomingRecurringRow(
                            recurringReminder: item.recurring,
                            nextDate: item.date
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getUpcomingRecurringReminders() -> [(recurring: RecurringReminder, date: Date)] {
        let calendar = Calendar.current
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        
        return recurringReminders
            .filter { $0.isActive }
            .compactMap { recurring in
                guard let nextDue = recurring.nextDue,
                      nextDue <= nextWeek else { return nil }
                return (recurring, nextDue)
            }
            .sorted { $0.date < $1.date }
    }
}

// MARK: - Supporting Views

struct QuickTemplateCard: View {
    let template: ReminderTemplate
    @Environment(\.modelContext) private var context
    @State private var recurringManager = RecurringRemindersManager.shared
    
    var body: some View {
        Button {
            let _ = recurringManager.createReminderFromTemplate(template, context: context)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: template.icon)
                        .foregroundColor(Color(hex: template.colorHex) ?? .blue)
                    
                    Spacer()
                    
                    Text("\(template.usageCount)")
                        .font(AppTheme.Typography.caption2)
                        .secondaryText()
                }
                
                Text(template.name)
                    .font(AppTheme.Typography.body)
                    .fontWeight(.medium)
                    .primaryText()
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(template.category)
                    .font(AppTheme.Typography.caption2)
                    .secondaryText()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct CategoryChip: View {
    let category: String
    @State private var isSelected = false
    
    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            Text(category)
                .font(AppTheme.Typography.caption1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surfaceLight,
                    in: Capsule()
                )
                .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
        }
    }
}

struct TemplateRow: View {
    let template: ReminderTemplate
    @Environment(\.modelContext) private var context
    @State private var recurringManager = RecurringRemindersManager.shared
    @State private var showingDetails = false
    
    var body: some View {
        Button {
            showingDetails = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: template.icon)
                    .foregroundColor(Color(hex: template.colorHex) ?? .blue)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(AppTheme.Typography.body)
                        .fontWeight(.medium)
                        .primaryText()
                        .lineLimit(1)
                    
                    Text(template.title)
                        .font(AppTheme.Typography.caption1)
                        .secondaryText()
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(template.category)
                            .font(AppTheme.Typography.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.Colors.primary.opacity(0.2), in: Capsule())
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        if template.usageCount > 0 {
                            Text("Used \(template.usageCount) times")
                                .font(AppTheme.Typography.caption2)
                                .secondaryText()
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    let _ = recurringManager.createReminderFromTemplate(template, context: context)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(AppTheme.Colors.primary)
                        .imageScale(.large)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 8))
        }
        .sheet(isPresented: $showingDetails) {
            // TODO: Implement TemplateDetailView
            NavigationStack {
                VStack {
                    Text("Template Details - Coming Soon")
                    Text("Template: \(template.name)")
                        .font(.headline)
                }
                .navigationTitle("Template Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingDetails = false
                        }
                    }
                }
            }
        }
    }
}

struct RecurringReminderRow: View {
    let recurringReminder: RecurringReminder
    @State private var showingDetails = false
    
    var body: some View {
        Button {
            showingDetails = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recurringReminder.templateTitle)
                        .font(AppTheme.Typography.body)
                        .fontWeight(.medium)
                        .primaryText()
                        .lineLimit(1)
                    
                    if let rule = recurringReminder.recurrenceRule {
                        Text(rule.pattern.displayName)
                            .font(AppTheme.Typography.caption1)
                            .secondaryText()
                    }
                    
                    if let nextDue = recurringReminder.nextDue {
                        Text("Next: \(nextDue, style: .date)")
                            .font(AppTheme.Typography.caption2)
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(recurringReminder.generatedReminders.count)")
                        .font(AppTheme.Typography.title3)
                        .fontWeight(.semibold)
                        .primaryText()
                    
                    Text("Generated")
                        .font(AppTheme.Typography.caption2)
                        .secondaryText()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 8))
        }
        .sheet(isPresented: $showingDetails) {
            // TODO: Implement RecurringReminderDetailView
            NavigationStack {
                VStack {
                    Text("Recurring Reminder Details - Coming Soon")
                    Text("Reminder: \(recurringReminder.templateTitle)")
                        .font(.headline)
                }
                .navigationTitle("Recurring Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingDetails = false
                        }
                    }
                }
            }
        }
    }
}

struct UpcomingRecurringRow: View {
    let recurringReminder: RecurringReminder
    let nextDate: Date
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(recurringReminder.templateTitle)
                    .font(AppTheme.Typography.body)
                    .primaryText()
                    .lineLimit(1)
                
                Text(nextDate, style: .relative)
                    .font(AppTheme.Typography.caption1)
                    .secondaryText()
            }
            
            Spacer()
            
            Text(nextDate, style: .time)
                .font(AppTheme.Typography.caption1)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppTheme.Typography.title2)
                .fontWeight(.bold)
                .primaryText()
            
            Text(title)
                .font(AppTheme.Typography.caption2)
                .secondaryText()
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(AppTheme.Typography.headline)
                    .primaryText()
                
                Text(subtitle)
                    .font(AppTheme.Typography.caption1)
                    .secondaryText()
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 32)
    }
}

#Preview {
    TemplatesView()
        .modelContainer(for: [ReminderTemplate.self, RecurringReminder.self, RecurrenceRule.self])
}
