import SwiftUI
import SwiftData
import os

struct ListsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var sections: [ListSection] = []
    @State private var lists: [ReminderList] = []
    @State private var allReminders: [Reminder] = []
    @State private var allTags: [Tag] = []
    @State private var newListName: String = ""
    @State private var selectedSection: ListSection?
    @State private var showingSectionSheet = false
    @State private var showingSmartListSheet = false
    @State private var newSectionName = ""
    @State private var selectedList: ReminderList?
    @State private var isCreatingSection = false

    // Smart list creation state
    @State private var smartListName: String = ""
    @State private var smartListRuleType: SmartListRule.RuleType = .tag
    @State private var selectedTagName: String = ""
    @State private var selectedPriority: Priority = .high
    
    // Feature Flags & State
    @State private var isSlumpMode: Bool = false
    @StateObject private var bioAuth = BiometricAuthManager.shared
    @State private var pendingProtectedList: ReminderList?

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad layout - use sidebar
                NavigationSplitView {
                    masterView
                } detail: {
                    if let selectedList = selectedList {
                        ListDetailView(list: selectedList, allReminders: allReminders)
                    } else {
                        Text("Select a list")
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // iPhone layout - use navigation
                NavigationStack {
                    masterView
                }
            }
        }
        .task {
            await loadListData()
        }
    }
    
    private var masterView: some View {
        VStack {
            // Header
            HStack {
                Text("Lists")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                
                // Menu for creating lists, smart lists, and sections
                Menu {
                    Button {
                        newListName = ""
                        newSectionName = ""
                        selectedSection = nil
                        isCreatingSection = false
                        showingSectionSheet = true
                    } label: {
                        Label("New List", systemImage: "plus")
                    }

                    Button {
                        smartListName = ""
                        smartListRuleType = .tag
                        selectedTagName = ""
                        selectedPriority = .high
                        showingSmartListSheet = true
                    } label: {
                        Label("New Smart List", systemImage: "sparkles")
                    }

                    Divider()

                    Button {
                        newListName = ""
                        newSectionName = ""
                        isCreatingSection = true
                        showingSectionSheet = true
                    } label: {
                        Label("New Section", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
                
                // Slump Mode Toggle
                Button(action: { isSlumpMode.toggle() }) {
                    Image(systemName: isSlumpMode ? "battery.25" : "battery.100")
                        .font(.title2)
                        .foregroundStyle(isSlumpMode ? .green : .secondary)
                }
                .padding(.leading, 8)
            }
            .padding()
            
            // Content
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Smart Lists
                    if !lists.filter({ $0.isSmart }).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Smart Lists")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(lists.filter { $0.isSmart }) { list in
                                listRow(for: list)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Slump Mode Indicator
                    if isSlumpMode {
                        HStack {
                            Image(systemName: "battery.25")
                                .foregroundColor(.green)
                            Text("Slump Mode Active: Showing Low Energy tasks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Sections
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.name)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if let sectionLists = section.lists, !sectionLists.isEmpty {
                                ForEach(sectionLists) { list in
                                    listRow(for: list)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    // Unsorted Lists
                    if !unsectionedLists.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Other Lists")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(unsectionedLists) { list in
                                listRow(for: list)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.bottom)
            }
        }
        .sheet(isPresented: $showingSectionSheet) {
            NavigationStack {
                VStack(spacing: 20) {
                    if isCreatingSection {
                        // New Section Sheet
                        VStack(alignment: .leading, spacing: 16) {
                            Text("New Section")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            TextField("Section name", text: $newSectionName)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding()
                    } else {
                        // New List Sheet
                        VStack(alignment: .leading, spacing: 16) {
                            Text("New List")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            TextField("List name", text: $newListName)
                                .textFieldStyle(.roundedBorder)
                            
                            if !sections.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Section (optional)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("Section", selection: $selectedSection) {
                                        Text("No section").tag(nil as ListSection?)
                                        ForEach(sections) { section in
                                            Text(section.name).tag(section as ListSection?)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                        }
                        .padding()
                    }
                }
                .navigationTitle(isCreatingSection ? "New Section" : "New List")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingSectionSheet = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            if isCreatingSection {
                                createNewSection()
                            } else {
                                createNewList()
                            }
                            showingSectionSheet = false
                        }
                        .disabled(isCreatingSection ? newSectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingSmartListSheet) {
            smartListCreationSheet
        }
        .navigationDestination(item: $pendingProtectedList) { list in
            ListDetailView(list: list, allReminders: allReminders, isSlumpMode: isSlumpMode)
        }
    }

    // MARK: - Smart List Creation Sheet
    private var smartListCreationSheet: some View {
        NavigationStack {
            Form {
                Section("Smart List Name") {
                    TextField("Enter name", text: $smartListName)
                }

                Section("Filter By") {
                    Picker("Rule Type", selection: $smartListRuleType) {
                        Text("Tag").tag(SmartListRule.RuleType.tag)
                        Text("Priority").tag(SmartListRule.RuleType.priority)
                        Text("Due Today").tag(SmartListRule.RuleType.dueToday)
                        Text("Overdue").tag(SmartListRule.RuleType.overdue)
                    }
                    .pickerStyle(.segmented)
                }

                if smartListRuleType == .tag {
                    Section("Select Tag") {
                        if allTags.isEmpty {
                            Text("No tags available")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            Picker("Tag", selection: $selectedTagName) {
                                Text("Select a tag").tag("")
                                ForEach(allTags, id: \.name) { tag in
                                    HStack {
                                        Circle()
                                            .fill(Color(hex: tag.colorHex) ?? .blue)
                                            .frame(width: 12, height: 12)
                                        Text(tag.name)
                                    }
                                    .tag(tag.name)
                                }
                            }
                        }

                        // Quick tag creation
                        HStack {
                            TextField("Or create new tag", text: $selectedTagName)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                if smartListRuleType == .priority {
                    Section("Select Priority") {
                        Picker("Priority", selection: $selectedPriority) {
                            ForEach(Priority.allCases) { priority in
                                Text(priority.title).tag(priority)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.headline)

                        Text(smartListPreviewDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("New Smart List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingSmartListSheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createSmartList()
                        showingSmartListSheet = false
                    }
                    .disabled(smartListName.isEmpty || (smartListRuleType == .tag && selectedTagName.isEmpty))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var smartListPreviewDescription: String {
        switch smartListRuleType {
        case .tag:
            if selectedTagName.isEmpty {
                return "Select a tag to filter reminders"
            }
            return "Shows all reminders tagged with \"\(selectedTagName)\""
        case .priority:
            return "Shows all \(selectedPriority.title.lowercased()) priority reminders"
        case .dueToday:
            return "Shows all reminders due today"
        case .overdue:
            return "Shows all overdue reminders"
        }
    }

    private func createSmartList() {
        guard !smartListName.isEmpty else { return }

        var rules: [SmartListRule] = []

        switch smartListRuleType {
        case .tag:
            guard !selectedTagName.isEmpty else { return }
            rules.append(SmartListRule(type: .tag, tagName: selectedTagName))
        case .priority:
            rules.append(SmartListRule(type: .priority, priority: selectedPriority))
        case .dueToday:
            rules.append(SmartListRule(type: .dueToday))
        case .overdue:
            rules.append(SmartListRule(type: .overdue))
        }

        let smartList = ReminderList(name: smartListName, isSmart: true, rules: rules)
        context.insert(smartList)

        do {
            try context.save()
            Task {
                await SearchSpotlightManager.shared.syncList(smartList)
            }
            // Reload lists to show the new smart list
            Task { await loadListData() }
        } catch {
            Logger(subsystem: "a-do", category: "SmartLists").error("Failed to create smart list: \(String(describing: error))")
        }
    }

    private func listRow(for list: ReminderList) -> some View {
        Group {
            if horizontalSizeClass == .regular {
                smartListRowContent(for: list)
                    .tag(list)
            } else {
                if list.isProtected && !bioAuth.isUnlocked {
                     Button {
                         authenticateAndOpen(list)
                     } label: {
                         smartListRowContent(for: list)
                     }
                } else {
                     NavigationLink { ListDetailView(list: list, allReminders: allReminders, isSlumpMode: isSlumpMode) } label: {
                         smartListRowContent(for: list)
                     }
                     .contextMenu {
                         Button(list.isProtected ? "Unlock List" : "Lock List (Privacy Mode)") {
                             list.isProtected.toggle()
                         }
                         Button("Delete", role: .destructive) {
                             deleteList(list)
                         }
                     }
                }
            }
        }
    }
    
    private func authenticateAndOpen(_ list: ReminderList) {
        Task {
            if await bioAuth.authenticateUser(reason: "Unlock \(list.name)") {
                // Upon success, trigger navigation
                pendingProtectedList = list
            }
        }
    }

    private func smartListRowContent(for list: ReminderList) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: list.isSmart ? smartListIcon(for: list) : (list.isProtected ? (bioAuth.isUnlocked ? "lock.open.fill" : "lock.fill") : "list.bullet"))
                .foregroundColor(list.isProtected ? (bioAuth.isUnlocked ? .green : .orange) : (list.isSmart ? .purple : .blue))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(list.name)
                    .font(.body)

                if list.isSmart, let description = smartListDescription(for: list) {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Count badge
            let count = SmartListEngine.reminders(for: list, from: allReminders).count
            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(list.isSmart ? Color.purple : Color.blue)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }

    private func smartListIcon(for list: ReminderList) -> String {
        guard let rule = list.rules.first else { return "sparkles" }
        switch rule.type {
        case .tag: return "tag.fill"
        case .priority: return "exclamationmark.3"
        case .dueToday: return "calendar"
        case .overdue: return "clock.badge.exclamationmark"
        }
    }

    private func smartListDescription(for list: ReminderList) -> String? {
        guard let rule = list.rules.first else { return nil }
        switch rule.type {
        case .tag:
            if let tagName = rule.tagName {
                return "Tagged: \(tagName)"
            }
            return nil
        case .priority:
            if let priority = rule.priority {
                return "\(priority.title) priority"
            }
            return nil
        case .dueToday:
            return "Due today"
        case .overdue:
            return "Overdue items"
        }
    }
    
    private var unsectionedLists: [ReminderList] {
        lists.filter { !$0.isSmart && $0.section == nil }
    }
    
    private func createNewList() {
        guard !newListName.isEmpty else { return }
        
        let newList = ReminderList(name: newListName)
        if let selectedSection = selectedSection {
            newList.section = selectedSection
        }
        
        context.insert(newList)
        
        do {
            try context.save()
            Task {
                await SearchSpotlightManager.shared.syncList(newList)
            }
            newListName = ""
            selectedSection = nil
        } catch {
            // Handle error silently in production
        }
    }
    
    private func createNewSection() {
        guard !newSectionName.isEmpty else { return }
        
        let newSection = ListSection(name: newSectionName, order: sections.count)
        context.insert(newSection)
        
        do {
            try context.save()
            newSectionName = ""
        } catch {
            // Handle error silently in production
        }
    }

    private func deleteList(_ list: ReminderList) {
        let listName = list.name
        context.delete(list)

        do {
            try context.save()
            Task {
                await SearchSpotlightManager.shared.removeList(name: listName)
            }
        } catch {
            Logger(subsystem: "a-do", category: "SmartLists").error("Failed to delete list: \(String(describing: error))")
        }
    }
    
    // MARK: - Data Loading

    private func loadListData() async {
        // Capture container for background context
        let container = context.container

        // Load persistent IDs on background thread to avoid blocking UI
        let (sectionIDs, listIDs, reminderIDs, tagIDs) = await Task.detached {
            let backgroundContext = ModelContext(container)

            // Load section IDs
            let sectionsDescriptor = FetchDescriptor<ListSection>(
                sortBy: [SortDescriptor(\.order)]
            )
            let sections = (try? backgroundContext.fetch(sectionsDescriptor)) ?? []
            let sectionIDs = sections.map { $0.persistentModelID }

            // Load list IDs
            let listsDescriptor = FetchDescriptor<ReminderList>()
            let lists = (try? backgroundContext.fetch(listsDescriptor)) ?? []
            let listIDs = lists.map { $0.persistentModelID }

            // Load only incomplete reminder IDs
            var remindersDescriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate<Reminder> { !$0.isCompleted }
            )
            remindersDescriptor.fetchLimit = 300
            let reminders = (try? backgroundContext.fetch(remindersDescriptor)) ?? []
            let reminderIDs = reminders.map { $0.persistentModelID }

            // Load tag IDs
            let tagsDescriptor = FetchDescriptor<Tag>(
                sortBy: [SortDescriptor(\.name)]
            )
            let tags = (try? backgroundContext.fetch(tagsDescriptor)) ?? []
            let tagIDs = tags.map { $0.persistentModelID }

            return (sectionIDs, listIDs, reminderIDs, tagIDs)
        }.value

        // Re-fetch objects on main context to ensure relationships are properly loaded
        await MainActor.run {
            self.sections = sectionIDs.compactMap { context.model(for: $0) as? ListSection }
            self.lists = listIDs.compactMap { context.model(for: $0) as? ReminderList }
            self.allReminders = reminderIDs.compactMap { context.model(for: $0) as? Reminder }
            self.allTags = tagIDs.compactMap { context.model(for: $0) as? Tag }
        }
    }
}

struct ListDetailView: View {
    let list: ReminderList
    let allReminders: [Reminder]
    var isSlumpMode: Bool = false
    @Environment(\.modelContext) private var context
    @State private var selectedReminder: Reminder?
    @State private var showingAddReminderSheet = false

    var body: some View {
        List {
            ForEach(listReminders) { reminder in
                ReminderRowView(reminder: reminder)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedReminder = reminder
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            deleteReminder(reminder)
                        }
                        Button("Edit") {
                            selectedReminder = reminder
                        }
                        .tint(.blue)
                    }
            }
        }
        .navigationTitle(list.name)
        .sheet(item: $selectedReminder) { reminder in
            NavigationStack {
                ReminderFormView(existingReminder: reminder)
            }
        }
        .sheet(isPresented: $showingAddReminderSheet) {
            NavigationStack {
                ReminderFormView(list: list)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddReminderSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }

    }
    
    private var listReminders: [Reminder] {
        if list.isSmart {
            // Use SmartListEngine to filter reminders based on smart list rules
            return SmartListEngine.reminders(for: list, from: allReminders)
        } else {
            // For regular lists, return reminders directly associated with the list
            let rawReminders = list.reminders ?? []
            if isSlumpMode {
                return rawReminders.filter { $0.energyLevel == .low }
            }
            return rawReminders
        }
    }
    
    private func deleteReminder(_ reminder: Reminder) {
        context.delete(reminder)
        
        do {
            try context.save()
        } catch {
            // Handle error silently in production
        }
    }
}

struct ReminderRowView: View {
    let reminder: Reminder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(reminder.title)
                    .font(.headline)
                    .strikethrough(reminder.isCompleted)
                
                Spacer()
                
                if reminder.priority == .high {
                    Image(systemName: "exclamationmark.3")
                        .foregroundColor(.red)
                }
            }
            
            if let details = reminder.details, !details.isEmpty {
                Text(details)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if let dueDate = reminder.dueDate {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text(dueDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if dueDate < Date() && !reminder.isCompleted {
                        Text("Overdue")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ListsView()
        .modelContainer(for: Reminder.self, inMemory: true)
}

