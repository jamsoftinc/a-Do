import SwiftUI
import SwiftData
import os

struct ListsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var sections: [ListSection] = []
    @State private var lists: [ReminderList] = []
    @State private var allReminders: [Reminder] = []
    @State private var newListName: String = ""
    @State private var selectedSection: ListSection?
    @State private var showingSectionSheet = false
    @State private var newSectionName = ""
    @State private var selectedList: ReminderList?
    @State private var isCreatingSection = false

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
                
                // Separate buttons for New List and New Section
                HStack(spacing: 12) {
                    Button {
                        newListName = ""
                        newSectionName = ""
                        selectedSection = nil
                        isCreatingSection = false
                        showingSectionSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.caption)
                            Text("New List")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.accent)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button {
                        newListName = ""
                        newSectionName = ""
                        isCreatingSection = true
                        showingSectionSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus")
                                .font(.caption)
                            Text("New Section")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.primary)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
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
                        .disabled(isCreatingSection ? newSectionName.isEmpty : newListName.isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private func listRow(for list: ReminderList) -> some View {
        Group {
            if horizontalSizeClass == .regular {
                Text(list.name)
                    .tag(list)
            } else {
                NavigationLink(list.name) { ListDetailView(list: list, allReminders: allReminders) }
            }
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
    
    // MARK: - Data Loading
    
    private func loadListData() async {
        // Load data on background thread
        let (loadedSections, loadedLists, loadedReminders) = await Task.detached {
            let backgroundContext = ModelContext(self.context.container)
            
            // Load sections
            let sectionsDescriptor = FetchDescriptor<ListSection>(
                sortBy: [SortDescriptor(\.order)]
            )
            let sections = (try? backgroundContext.fetch(sectionsDescriptor)) ?? []
            
            // Load lists
            let listsDescriptor = FetchDescriptor<ReminderList>()
            let lists = (try? backgroundContext.fetch(listsDescriptor)) ?? []
            
            // Load only incomplete reminders
            var remindersDescriptor = FetchDescriptor<Reminder>(
                predicate: #Predicate<Reminder> { !$0.isCompleted }
            )
            remindersDescriptor.fetchLimit = 300
            let reminders = (try? backgroundContext.fetch(remindersDescriptor)) ?? []
            
            return (sections, lists, reminders)
        }.value
        
        await MainActor.run {
            self.sections = loadedSections
            self.lists = loadedLists
            self.allReminders = loadedReminders
        }
    }
}

struct ListDetailView: View {
    let list: ReminderList
    let allReminders: [Reminder]
    @Environment(\.modelContext) private var context
    @State private var showingEditSheet = false
    
    var body: some View {
        List {
            ForEach(listReminders) { reminder in
                ReminderRowView(reminder: reminder)
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            deleteReminder(reminder)
                        }
                        Button("Edit") {
                            showingEditSheet = true
                        }
                        .tint(.blue)
                    }
            }
        }
        .navigationTitle(list.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                ReminderFormView(existingReminder: listReminders.first)
            }
        }
    }
    
    private var listReminders: [Reminder] {
        // Temporarily disabled - list relationship commented out
        // allReminders.filter { $0.list == list }
        // Return all reminders for now
        return allReminders
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
                    
                    if reminder.dueDate! < Date() && !reminder.isCompleted {
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


