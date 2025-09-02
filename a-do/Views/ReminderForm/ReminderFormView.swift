import SwiftUI
import SwiftData
import os

#if canImport(MapKit)
import MapKit
#endif

#if canImport(CoreLocation)
import CoreLocation
#endif

@available(iOS 17.0, *)
struct ReminderFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var allTags: [Tag]

    @State private var viewModel = ReminderFormViewModel()
    @State private var showingCancelConfirmation = false
    @State private var showingDeleteConfirmation = false
    let existingReminder: Reminder?
    
    init(existingReminder: Reminder? = nil) {
        self.existingReminder = existingReminder
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Essential Details Card
                    essentialDetailsCard
                    
                    // Quick Actions Card
                    quickActionsCard
                    
                    // Advanced Features Card
                    advancedFeaturesCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.Gradients.background.ignoresSafeArea())
            .navigationTitle(existingReminder == nil ? "New Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarButtons }
            .onAppear { setupExistingReminder() }
            .sheet(isPresented: $viewModel.showNotePicker) {
                AppleNotePickerView(selectedNote: $viewModel.attachedNote)
            }
            .confirmationDialog(
                "Discard Changes?",
                isPresented: $showingCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) {
                    performCancel()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("Are you sure you want to discard this reminder? All your changes will be lost.")
            }
            .confirmationDialog(
                "Delete Reminder?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    performDelete()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete '\(viewModel.title)'? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Essential Details Card
    private var essentialDetailsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(AppTheme.Typography.headline)
                        .primaryText()
                    TextField("What needs to be done?", text: $viewModel.title)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                        .primaryText()
                }
                
                // Due Date & Priority
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Due Date")
                            .font(AppTheme.Typography.subheadline)
                            .primaryText()
                        DatePicker("", selection: Binding(
                            get: { viewModel.dueDate ?? Date() },
                            set: { viewModel.dueDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority")
                            .font(AppTheme.Typography.subheadline)
                            .primaryText()
                        Picker("", selection: $viewModel.priority) {
                            ForEach(Priority.allCases) { p in 
                                Text(p.title).tag(p) 
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(AppTheme.Typography.subheadline)
                        .primaryText()
                    TextField("Add details...", text: $viewModel.details, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                        .primaryText()
                        .lineLimit(3...6)
                }
            }
        }
    }
    
    // MARK: - Quick Actions Card
    private var quickActionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Quick Actions")
                    .font(AppTheme.Typography.headline)
                    .primaryText()
                
                // Tags
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(AppTheme.Typography.subheadline)
                        .primaryText()
                    
                    if allTags.isEmpty {
                        Text("No tags available")
                            .font(AppTheme.Typography.caption1)
                            .secondaryText()
                    } else {
                        FlowLayout(alignment: .leading, spacing: 8) {
                            ForEach(allTags) { tag in
                                let isSelected = viewModel.selectedTags.contains(where: { $0.persistentModelID == tag.persistentModelID })
                                Text(tag.name)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background((Color(hex: tag.colorHex) ?? .white).opacity(isSelected ? 0.9 : 0.3), in: Capsule())
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
                    }
                    
                    NavigationLink("Manage Tags", destination: TagsView())
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                // Notifications
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notifications")
                        .font(AppTheme.Typography.subheadline)
                        .primaryText()
                    LeadTimesPicker(leadTimes: $viewModel.leadTimes)
                }
                
                // Voice Recording
                VStack(alignment: .leading, spacing: 8) {
                    Text("Voice Recording")
                        .font(AppTheme.Typography.subheadline)
                        .primaryText()
                    
                    if let voiceReminder = viewModel.voiceReminder {
                        // Show existing voice reminder
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundColor(.white)
                                Text("Voice Recording")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Delete") {
                                    viewModel.deleteVoiceRecording()
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                            
                            Text(voiceReminder.transcribedText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Duration: \(Int(voiceReminder.recordingDuration))s")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button {
                                    Task {
                                        await viewModel.playVoiceRecording()
                                    }
                                } label: {
                                    Image(systemName: "play.circle.fill")
                                        .foregroundColor(.white)
                                        .imageScale(.small)
                                }
                            }
                        }
                    } else {
                        // Show recording interface
                        VStack(alignment: .leading, spacing: 8) {
                            if viewModel.isRecordingVoice {
                                HStack {
                                    Image(systemName: "record.circle")
                                        .foregroundColor(.red)
                                        .imageScale(.small)
                                    Text("Recording... \(Int(AudioManager.shared.recordingDuration))s")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Spacer()
                                    Button("Stop") {
                                        viewModel.stopVoiceRecording()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                            } else {
                                Button {
                                    Task {
                                        await viewModel.startVoiceRecording()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "mic.circle.fill")
                                            .foregroundColor(.white)
                                        Text("Start Recording")
                                            .foregroundColor(.white)
                                    }
                                }
                                .disabled(viewModel.isRecordingVoice)
                            }
                            
                            if AudioManager.shared.isTranscribing {
                                HStack {
                                    Image(systemName: "text.bubble")
                                        .foregroundColor(.orange)
                                        .imageScale(.small)
                                    Text("Transcribing...")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            if let error = viewModel.voiceRecordingError {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .imageScale(.small)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Advanced Features Card
    private var advancedFeaturesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Advanced Features")
                    .font(AppTheme.Typography.headline)
                    .primaryText()
                
                // Calendar Invite
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calendar Invite")
                        .font(AppTheme.Typography.subheadline)
                        .primaryText()
                    
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
                            VStack(alignment: .leading, spacing: 8) {
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
                                
                                TextField("Location (optional)", text: $viewModel.calendarLocation)
                                    .textFieldStyle(.plain)
                                    .padding(AppTheme.Spacing.sm)
                                    .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                                    .primaryText()
                                
                                TextField("Attendees (comma-separated emails)", text: $viewModel.calendarAttendees)
                                    .textFieldStyle(.plain)
                                    .padding(AppTheme.Spacing.sm)
                                    .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                                    .primaryText()
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                        }
                    }
                }
                
                // Auto Message
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto Message")
                        .font(AppTheme.Typography.subheadline)
                        .primaryText()
                    
                    Toggle("Text tagged contacts when due", isOn: $viewModel.autoTextTaggedContacts)
                    Toggle("Text me (my number)", isOn: $viewModel.autoTextMe)
                    
                    NavigationLink("Tag People") {
                        TagPeopleView(reminderTitle: viewModel.title)
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                }
                
                // Apple Note
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apple Note")
                        .font(AppTheme.Typography.subheadline)
                        .primaryText()
                    
                    if let attachedNote = viewModel.attachedNote {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                AppleNoteAttachmentView(noteAttachment: attachedNote)
                                Spacer()
                                Button("Remove") {
                                    viewModel.attachedNote = nil
                                }
                                .foregroundColor(.red)
                                .font(.caption)
                            }
                        }
                    } else {
                        Button("Attach Apple Note") {
                            viewModel.showNotePicker = true
                        }
                        .foregroundColor(.white)
                        .font(.caption)
                    }
                }
                
                // Location Trigger
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location Trigger")
                        .font(AppTheme.Typography.subheadline)
                        .primaryText()
                    
                    TextField("Label", text: $viewModel.locationLabel)
                        .textFieldStyle(.plain)
                        .padding(AppTheme.Spacing.sm)
                        .background(AppTheme.Colors.surfaceLight, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                        .primaryText()
                    
                    // Map View
                    if viewModel.hasValidCoordinates {
                        #if canImport(MapKit)
                        LocationMapView(
                            latitude: viewModel.locationLatitude,
                            longitude: viewModel.locationLongitude,
                            radius: viewModel.locationRadius,
                            label: viewModel.locationLabel.isEmpty ? "Current Location" : viewModel.locationLabel
                        )
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.secondary.opacity(0.2), lineWidth: 1)
                        )
                        #else
                        // Fallback when MapKit is not available
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.gray.opacity(0.3))
                            .frame(height: 200)
                            .overlay(
                                VStack {
                                    Image(systemName: "map")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                    Text("Map not available")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            )
                        #endif
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
                        .font(.caption)
                    }
                    .disabled(viewModel.isDetectingLocation)
                    .foregroundColor(.white)
                    
                    if let error = viewModel.locationDetectionError {
                        Text(error)
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
                    
                    HStack {
                        Text("Radius: \(Int(viewModel.locationRadius))m")
                            .font(.caption)
                        Spacer()
                        Stepper("", value: $viewModel.locationRadius, in: 50...1000, step: 25)
                            .labelsHidden()
                    }
                    
                    Picker("Trigger", selection: $viewModel.locationType) {
                        ForEach(LocationTriggerType.allCases) { t in 
                            Text(t.rawValue.capitalized).tag(t) 
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }
    
    // MARK: - Toolbar
    private var toolbarButtons: some ToolbarContent {
        Group {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    // Check if user has entered any data
                    let hasData = !viewModel.title.trimmingCharacters(in: .whitespaces).isEmpty ||
                                 !viewModel.details.trimmingCharacters(in: .whitespaces).isEmpty ||
                                 viewModel.dueDate != nil ||
                                 !viewModel.selectedTags.isEmpty ||
                                 !viewModel.leadTimes.isEmpty ||
                                 viewModel.voiceReminder != nil ||
                                 viewModel.attachedNote != nil ||
                                 !viewModel.locationLabel.isEmpty ||
                                 viewModel.createCalendarInvite ||
                                 !viewModel.calendarLocation.isEmpty ||
                                 !viewModel.calendarAttendees.isEmpty
                    
                    if hasData {
                        showingCancelConfirmation = true
                    } else {
                        performCancel()
                    }
                }
            }
            
            // Delete button - only show when editing existing reminder
            if existingReminder != nil {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete") {
                        showingDeleteConfirmation = true
                    }
                    .foregroundColor(.red)
                }
            }
            
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
                        await viewModel.createCalendarInviteFromReminder(context: context)
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
    }
    
    // MARK: - Cancel Function
    private func performCancel() {
        // Clean up any temporary resources
        if viewModel.isRecordingVoice {
            viewModel.stopVoiceRecording()
        }
        if viewModel.voiceReminder != nil {
            viewModel.deleteVoiceRecording()
        }
        dismiss()
    }
    
    // MARK: - Delete Function
    private func performDelete() {
        guard let existingReminder = existingReminder else { return }
        
        // Cancel any notifications for this reminder
        NotificationManager.shared.cancelNotifications(for: existingReminder.id)
        
        // Stop location monitoring if this reminder has location triggers
        if let locationTrigger = existingReminder.locationTrigger {
            LocationManager.shared.stopMonitoring(identifier: locationTrigger.label)
        }
        
        // Delete voice recording file if it exists
        if let voiceReminder = existingReminder.voiceReminder,
           let audioFileURL = voiceReminder.audioFileURL {
            try? FileManager.default.removeItem(at: audioFileURL)
        }
        
        // Remove from context and save
        context.delete(existingReminder)
        do {
            try context.save()
            Logger(subsystem: "a-do", category: "Reminders").info("Reminder deleted: '\(existingReminder.title)'")
        } catch {
            Logger(subsystem: "a-do", category: "Reminders").error("Failed to delete reminder: \(error.localizedDescription)")
        }
        
        dismiss()
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
            viewModel.voiceReminder = existing.voiceReminder
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
        FlowLayout(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            ForEach(options, id: \.1) { label, value in
                let isSelected = leadTimes.contains(value)
                Text(label)
                    .font(AppTheme.Typography.caption1)
                    .padding(.horizontal, AppTheme.Spacing.md).padding(.vertical, AppTheme.Spacing.sm)
                    .background((isSelected ? AppTheme.Colors.primary : AppTheme.Colors.primary.opacity(0.3)), in: Capsule())
                    .foregroundStyle(.white)
                    .onTapGesture {
                        if isSelected { leadTimes.removeAll { $0 == value } } else { leadTimes.append(value) }
                    }
            }
        }
    }
}

// MARK: - Location Map View
#if canImport(MapKit)
@available(iOS 17.0, *)
private struct LocationMapView: View {
    let latitude: Double
    let longitude: Double
    let radius: Double
    let label: String
    
    private var region: MKCoordinateRegion {
        // Calculate appropriate zoom level based on radius
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.002, radius / 111000.0 * 6), // Convert meters to degrees, with padding
            longitudeDelta: max(0.002, radius / 111000.0 * 6)
        )
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: span
        )
    }
    
    private var locationPin: LocationPin {
        LocationPin(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), title: label)
    }
    
    var body: some View {
        Map {
            Annotation(label, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) {
                VStack(spacing: 4) {
                    // Pin with shadow
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.white)
                        .font(.title)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                    
                    // Label with modern styling
                    if !label.isEmpty {
                        Text(label)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: Capsule())
                            .foregroundColor(.primary)
                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .overlay(
            // Radius circle overlay - positioned at center
            Circle()
                .stroke(.white.opacity(0.4), lineWidth: 2)
                .background(Circle().fill(.white.opacity(0.1)))
                .frame(width: radiusInPoints, height: radiusInPoints)
        )
        .allowsHitTesting(false) // Make map non-interactive
    }
    
    // Convert radius from meters to points for overlay circle
    private var radiusInPoints: CGFloat {
        // More accurate conversion based on map region
        let metersPerDegree = 111000.0 // Approximate meters per degree of latitude
        let degreesPerPoint = region.span.latitudeDelta / 200.0 // Assuming 200 points map height
        let metersPerPoint = metersPerDegree * degreesPerPoint
        return CGFloat(radius / metersPerPoint)
    }
}

private struct LocationPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
}

#endif

