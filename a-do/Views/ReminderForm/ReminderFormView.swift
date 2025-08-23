import SwiftUI
import SwiftData

struct ReminderFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var allTags: [Tag]

    @State private var viewModel = ReminderFormViewModel()
    let existingReminder: Reminder?
    
    init(existingReminder: Reminder? = nil) {
        self.existingReminder = existingReminder
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad layout - two-column form for better space utilization
            iPadLayout
        } else {
            // iPhone layout - single column
            iPhoneLayout
        }
    }
    
    // MARK: - iPad Layout
    private var iPadLayout: some View {
        NavigationView {
            HStack(spacing: 0) {
                // Left column
                Form {
                    basicDetailsSection
                    tagsSection
                    notificationsSection
                    calendarInviteSection
                }
                .frame(maxWidth: .infinity)
                
                // Right column
                Form {
                    autoMessageSection
                    tagPeopleSection
                    appleNoteSection
                    locationSection
                }
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.backgroundGradient)
            .navigationTitle(existingReminder == nil ? "New Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { saveToolbarButton }
            .onAppear { setupExistingReminder() }
            .sheet(isPresented: $viewModel.showNotePicker) {
                AppleNotePickerView(selectedNote: $viewModel.attachedNote)
            }
        }
    }
    
    // MARK: - iPhone Layout
    private var iPhoneLayout: some View {
        Form {
            basicDetailsSection
            tagsSection
            notificationsSection
            calendarInviteSection
            autoMessageSection
            tagPeopleSection
            appleNoteSection
            locationSection
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.backgroundGradient)
        .navigationTitle(existingReminder == nil ? "New Reminder" : "Edit Reminder")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { saveToolbarButton }
        .onAppear { setupExistingReminder() }
        .sheet(isPresented: $viewModel.showNotePicker) {
            AppleNotePickerView(selectedNote: $viewModel.attachedNote)
        }
    }
    
    // MARK: - Form Sections
    private var basicDetailsSection: some View {
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
    }
                
    private var tagsSection: some View {
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
    }
                
    private var notificationsSection: some View {
        Section("Notifications") {
            LeadTimesPicker(leadTimes: $viewModel.leadTimes)
        }
    }
    
    private var calendarInviteSection: some View {
        Section("Calendar Invite") {
            if viewModel.calendarInviteCreated {
                HStack {
                    Image(systemName: "calendar.badge.checkmark")
                        .foregroundColor(.orange)
                    Text("Calendar invite already created")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                Toggle("Create Calendar Event", isOn: $viewModel.createCalendarInvite)
                
                if viewModel.createCalendarInvite {
                    VStack(alignment: .leading, spacing: 12) {
                        // Duration picker
                        HStack {
                            Text("Duration:")
                            Spacer()
                            Picker("Duration", selection: $viewModel.calendarDuration) {
                                Text("15 min").tag(TimeInterval(15 * 60))
                                Text("30 min").tag(TimeInterval(30 * 60))
                                Text("1 hour").tag(TimeInterval(60 * 60))
                                Text("2 hours").tag(TimeInterval(2 * 60 * 60))
                                Text("All day").tag(TimeInterval(24 * 60 * 60))
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        // Location field
                        TextField("Location (optional)", text: $viewModel.calendarLocation)
                        
                        // Attendees field
                        TextField("Attendees (comma-separated emails)", text: $viewModel.calendarAttendees)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        
                        // Status messages
                        if viewModel.calendarInviteCreated {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Calendar invite created successfully")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                        
                        if let error = viewModel.calendarInviteError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
    }
    private var autoMessageSection: some View {
        Section("Auto Message") {
            Toggle("Text tagged contacts when due", isOn: $viewModel.autoTextTaggedContacts)
            Toggle("Text me (my number)", isOn: $viewModel.autoTextMe)
        }
    }
                
    private var tagPeopleSection: some View {
        Section("Tag People") {
            NavigationLink("Add People") {
                TagPeopleView(reminderTitle: viewModel.title)
            }
        }
    }
            
    private var appleNoteSection: some View {
        Section("Apple Note") {
            if let attachedNote = viewModel.attachedNote {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        AppleNoteAttachmentView(noteAttachment: attachedNote)
                        Spacer()
                        Button("Remove") {
                            viewModel.attachedNote = nil
                        }
                        .foregroundColor(.red)
                    }
                }
            } else {
                Button("Attach Apple Note") {
                    viewModel.showNotePicker = true
                }
                .foregroundColor(.blue)
            }
        }
    }
            
    private var locationSection: some View {
        Section("Location Trigger") {
            TextField("Label", text: $viewModel.locationLabel)
            
            HStack {
                TextField("Latitude", value: $viewModel.locationLatitude, format: .number)
                TextField("Longitude", value: $viewModel.locationLongitude, format: .number)
            }
            
            Button {
                Task {
                    await viewModel.detectCurrentLocation()
                }
            } label: {
                HStack {
                    Image(systemName: "location.fill")
                    Text(viewModel.isDetectingLocation ? "Detecting..." : "Use Current Location")
                }
            }
            .disabled(viewModel.isDetectingLocation)
            .foregroundColor(.blue)
            
            if let error = viewModel.locationDetectionError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if !viewModel.locationLabel.isEmpty && !viewModel.hasValidCoordinates {
                Text("Invalid coordinates. Latitude: -90 to 90, Longitude: -180 to 180")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if viewModel.hasValidCoordinates {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Valid coordinates detected")
                        .font(.caption)
                        .foregroundColor(.green)
                }
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
    
    // MARK: - Toolbar
    private var saveToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                let saved = viewModel.save(context: context, existing: existingReminder)
                NotificationManager.shared.cancelNotifications(for: saved.id)
                Task {
                    await NotificationManager.shared.scheduleNotifications(
                        for: saved.id,
                        dueDate: saved.dueDate,
                        leadTimes: saved.notifications?.map { $0.leadTimeSeconds } ?? [],
                        title: saved.title
                    )
                    
                    // Create calendar invite if requested
                    await viewModel.createCalendarInviteFromReminder()
                }
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
            }
            .disabled(viewModel.title.trimmingCharacters(in: .whitespaces).isEmpty ||
                     (!viewModel.locationLabel.isEmpty && !viewModel.hasValidCoordinates))
        }
    }
    
    // MARK: - Setup
    private func setupExistingReminder() {
        if let existing = existingReminder {
            viewModel.title = existing.title
            viewModel.details = existing.details ?? ""
            viewModel.dueDate = existing.dueDate
            viewModel.priority = existing.priority
            viewModel.selectedTags = existing.tags ?? []
            viewModel.leadTimes = existing.notifications?.map { $0.leadTimeSeconds } ?? []
            viewModel.autoTextTaggedContacts = existing.autoTextTaggedContacts
            viewModel.autoTextMe = existing.autoTextMe
            viewModel.attachedNote = existing.appleNote
            if let location = existing.locationTrigger {
                viewModel.locationLabel = location.label
                viewModel.locationLatitude = location.latitude
                viewModel.locationLongitude = location.longitude
                viewModel.locationRadius = location.radius
                viewModel.locationType = location.type
            }
            
            // For existing reminders, don't create calendar invites by default
            // as they likely already exist
            viewModel.createCalendarInvite = false
            viewModel.calendarDuration = 30 * 60
            viewModel.calendarLocation = ""
            viewModel.calendarAttendees = ""
            viewModel.calendarInviteCreated = existing.calendarInviteCreated
        } else {
            // For new reminders, try to pre-fill with current location
            Task {
                await viewModel.prefillWithCurrentLocation()
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

 


