import SwiftUI
import SwiftData
import os

struct ListsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \ListSection.order) private var sections: [ListSection]
    @Query private var lists: [ReminderList]
    @Query private var allReminders: [Reminder]
    @State private var newListName: String = ""
    @State private var selectedSection: ListSection?
    @State private var showingSectionSheet = false
    @State private var newSectionName = ""
    @State private var selectedList: ReminderList?

    var body: some View {
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
    
    private var masterView: some View {
        VStack {
            // Header
            HStack {
                Text("Lists")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Menu {
                    Button("New List") {
                        newListName = ""
                        selectedSection = nil
                        showingSectionSheet = true
                    }
                    Button("New Section") {
                        newSectionName = ""
                        showingSectionSheet = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
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
                    if newSectionName.isEmpty {
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
                    } else {
                        // New Section Sheet
                        VStack(alignment: .leading, spacing: 16) {
                            Text("New Section")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            TextField("Section name", text: $newSectionName)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding()
                    }
                }
                .navigationTitle(newSectionName.isEmpty ? "New List" : "New Section")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingSectionSheet = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            if newSectionName.isEmpty {
                                createNewList()
                            } else {
                                createNewSection()
                            }
                            showingSectionSheet = false
                        }
                        .disabled(newListName.isEmpty && newSectionName.isEmpty)
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
            print("Failed to save new list: \(error.localizedDescription)")
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
            print("Failed to save new section: \(error.localizedDescription)")
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
        allReminders.filter { $0.list == list }
    }
    
    private func deleteReminder(_ reminder: Reminder) {
        context.delete(reminder)
        
        do {
            try context.save()
        } catch {
            print("Failed to delete reminder: \(error.localizedDescription)")
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


