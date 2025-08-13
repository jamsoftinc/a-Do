import SwiftUI
import SwiftData
import os

struct ListsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ListSection.order) private var sections: [ListSection]
    @Query private var lists: [ReminderList]
    @Query private var allReminders: [Reminder]
    @State private var newListName: String = ""
    @State private var selectedSection: ListSection?
    @State private var showingSectionSheet = false
    @State private var newSectionName = ""

    var body: some View {
        List {
            // Smart Lists Section
            Section("Smart Lists") {
                ForEach(lists.filter { $0.isSmart }.sorted { $0.order < $1.order }) { list in
                    NavigationLink(list.name) { ListDetailView(list: list, allReminders: allReminders) }
                }
            }
            
            // Unsectioned Lists
            let unsectionedLists = lists.filter { !$0.isSmart && $0.section == nil }
            if !unsectionedLists.isEmpty {
                Section("Lists") {
                    ForEach(unsectionedLists.sorted { $0.order < $1.order }) { list in
                        listRow(for: list)
                    }
                }
            }
            
            // Sectioned Lists
            ForEach(sections) { section in
                Section {
                    ForEach(section.lists.sorted { $0.order < $1.order }) { list in
                        listRow(for: list)
                    }
                    
                    // Add list to this section
                    HStack {
                        TextField("New list in \(section.name)", text: $newListName)
                        Spacer()
                        Button("Add") { 
                            addList(to: section)
                        }.disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    HStack {
                        Circle()
                            .fill(Color(hex: section.colorHex) ?? .purple)
                            .frame(width: 8, height: 8)
                        Text(section.name)
                    }
                }
            }
            
            // Add new list without section
            Section {
                HStack {
                    TextField("New list", text: $newListName)
                    Spacer()
                    Button("Add") { addList() }.disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Lists")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingSectionSheet = true
                } label: {
                    Label("Add Section", systemImage: "folder.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingSectionSheet) {
            NavigationStack {
                Form {
                    TextField("Section Name", text: $newSectionName)
                }
                .navigationTitle("New Section")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { 
                            showingSectionSheet = false
                            newSectionName = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") { 
                            addSection()
                            showingSectionSheet = false
                        }.disabled(newSectionName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .task { SmartListEngine.ensureDefaultSmartLists(context: context) }
    }
    
    private func listRow(for list: ReminderList) -> some View {
        NavigationLink(list.name) { ListDetailView(list: list, allReminders: allReminders) }
            .contextMenu {
                if let section = list.section {
                    Button {
                        list.section = nil
                        try? context.save()
                    } label: {
                        Label("Remove from \(section.name)", systemImage: "folder.badge.minus")
                    }
                } else {
                    Menu {
                        ForEach(sections) { section in
                            Button {
                                list.section = section
                                try? context.save()
                            } label: {
                                Label(section.name, systemImage: "folder")
                            }
                        }
                    } label: {
                        Label("Move to Section", systemImage: "folder")
                    }
                }
                
                Button(role: .destructive) {
                    context.delete(list)
                    try? context.save()
                } label: {
                    Label("Delete List", systemImage: "trash")
                }
            }
    }

    private func addList(to section: ListSection? = nil) {
        let maxOrder = lists.filter { $0.section == section }.map { $0.order }.max() ?? 0
        let list = ReminderList(name: newListName)
        list.section = section
        list.order = maxOrder + 1
        context.insert(list)
        do { try context.save() } catch { Logger(subsystem: "Remember", category: "Lists").error("Add list failed: \(String(describing: error))") }
        newListName = ""
    }
    
    private func addSection() {
        let maxOrder = sections.map { $0.order }.max() ?? 0
        let section = ListSection(
            name: newSectionName, 
            order: maxOrder + 1,
            colorHex: Tag.defaultColors.randomElement() ?? "#7C4DFF"
        )
        context.insert(section)
        do { try context.save() } catch { Logger(subsystem: "Remember", category: "Lists").error("Add section failed: \(String(describing: error))") }
        newSectionName = ""
    }
}

struct ListDetailView: View {
    @Environment(\.modelContext) private var context
    let list: ReminderList
    let allReminders: [Reminder]

    var body: some View {
        List {
            ForEach(list.isSmart ? SmartListEngine.reminders(for: list, from: allReminders) : list.reminders) { reminder in
                HStack {
                    Text(reminder.title)
                    Spacer()
                    Text(reminder.priority.title).foregroundStyle(AppTheme.priorityColor(reminder.priority))
                }
            }
            .onDelete { indexSet in
                if list.isSmart { return }
                let reminders = list.reminders
                for index in indexSet { context.delete(reminders[index]) }
                do { try context.save() } catch { Logger(subsystem: "Remember", category: "Lists").error("Delete reminder failed: \(String(describing: error))") }
            }
        }
        .navigationTitle(list.name)
    }
}

