import SwiftUI
import SwiftData

struct ReminderFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var allTags: [Tag]

    @State private var viewModel = ReminderFormViewModel()
    let existingReminder: Reminder?
    
    init(existingReminder: Reminder? = nil) {
        self.existingReminder = existingReminder
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $viewModel.title)
                TextField("Notes", text: $viewModel.details, axis: .vertical)
                DatePicker(
                    "Due Date",
                    selection: Binding(
                        get: { viewModel.dueDate ?? Date() },
                        set: { viewModel.dueDate = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                Picker("Priority", selection: $viewModel.priority) {
                    ForEach(Priority.allCases) { p in Text(p.title).tag(p) }
                }
            }
                
            Section("Tags") {
                FlowLayout(alignment: .leading, spacing: 8) {
                    ForEach(allTags) { tag in
                        let isSelected = viewModel.selectedTags.contains(where: { $0.persistentModelID == tag.persistentModelID })
                        Text(tag.name)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background((Color(hex: tag.colorHex) ?? .blue).opacity(isSelected ? 0.9 : 0.3), in: Capsule())
                            .foregroundStyle(.white)
                            .onTapGesture {
                                if isSelected {
                                    viewModel.selectedTags.removeAll { $0.persistentModelID == tag.persistentModelID }
                                } else {
                                    viewModel.selectedTags.append(tag)
                                }
                            }
                    }
                }
                NavigationLink("Manage Tags", destination: TagsView())
            }
                
            Section("Notifications") {
                LeadTimesPicker(leadTimes: $viewModel.leadTimes)
            }
                
            Section("Tag People") {
                NavigationLink("Add People") {
                    TagPeopleView(reminderTitle: viewModel.title)
                }
            }
            
            Section("Location Trigger") {
                TextField("Label", text: $viewModel.locationLabel)
                HStack {
                    TextField("Latitude", value: $viewModel.locationLatitude, format: .number)
                    TextField("Longitude", value: $viewModel.locationLongitude, format: .number)
                }
                Stepper(value: $viewModel.locationRadius, in: 50...1000, step: 25) { 
                    Text("Radius: \(Int(viewModel.locationRadius))m") 
                }
                Picker("Trigger", selection: $viewModel.locationType) {
                    ForEach(LocationTriggerType.allCases) { t in 
                        Text(t.rawValue.capitalized).tag(t) 
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.backgroundGradient)
        .navigationTitle(existingReminder == nil ? "New Reminder" : "Edit Reminder")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Save") {
                let saved = viewModel.save(context: context, existing: existingReminder)
                NotificationManager.shared.cancelNotifications(for: saved.id)
                NotificationManager.shared.scheduleNotifications(
                    for: saved.id,
                    dueDate: saved.dueDate,
                    leadTimes: saved.notifications.map { $0.leadTimeSeconds },
                    title: saved.title
                )
                if !viewModel.locationLabel.isEmpty {
                    let notifyOnEntry = viewModel.locationType == .onArrival
                    let notifyOnExit = viewModel.locationType == .onDeparture
                    LocationManager.shared.startMonitoring(
                        label: viewModel.locationLabel,
                        latitude: viewModel.locationLatitude,
                        longitude: viewModel.locationLongitude,
                        radius: viewModel.locationRadius,
                        notifyOnEntry: notifyOnEntry,
                        notifyOnExit: notifyOnExit
                    )
                }
                dismiss()
            }.disabled(viewModel.title.trimmingCharacters(in: .whitespaces).isEmpty) }
        }
        .onAppear {
            if let existing = existingReminder {
                viewModel.title = existing.title
                viewModel.details = existing.details ?? ""
                viewModel.dueDate = existing.dueDate
                viewModel.priority = existing.priority
                viewModel.selectedTags = existing.tags
                viewModel.leadTimes = existing.notifications.map { $0.leadTimeSeconds }
                if let location = existing.locationTrigger {
                    viewModel.locationLabel = location.label
                    viewModel.locationLatitude = location.latitude
                    viewModel.locationLongitude = location.longitude
                    viewModel.locationRadius = location.radius
                    viewModel.locationType = location.type
                }
            }
        }
    }
}

private struct LeadTimesPicker: View {
    @Binding var leadTimes: [TimeInterval]
    private let options: [(String, TimeInterval)] = [
        ("5 min", 5*60), ("15 min", 15*60), ("1 hr", 3600), ("1 day", 86400)
    ]
    var body: some View {
        FlowLayout(alignment: .leading, spacing: 8) {
            ForEach(options, id: \.1) { label, value in
                let isSelected = leadTimes.contains(value)
                Text(label)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background((isSelected ? Color.purple : Color.purple.opacity(0.3)), in: Capsule())
                    .foregroundStyle(.white)
                    .onTapGesture {
                        if isSelected { leadTimes.removeAll { $0 == value } } else { leadTimes.append(value) }
                    }
            }
        }
    }
}

 


