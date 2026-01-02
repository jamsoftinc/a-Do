//
//  CreateListView.swift
//  a-do
//
//  Create list interface for workspaces
//

import SwiftUI
import SwiftData

struct CreateListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    private var collaborationManager = CollaborationManager.shared
    
    @State private var listName: String = ""
    @State private var listDescription: String = ""
    @State private var isSmartList: Bool = false
    @State private var selectedIcon: String = "list.bullet"
    @State private var selectedColor: String = "#007AFF"
    @State private var isCreating = false
    
    var workspace: Workspace

    init(workspace: Workspace) {
        self.workspace = workspace
    }

    private let icons = [
        "list.bullet", "list.bullet.rectangle", "list.number", "list.star",
        "folder", "folder.fill", "doc.text", "doc.text.fill",
        "calendar", "calendar.badge.plus", "clock", "clock.fill",
        "flag", "flag.fill", "star", "star.fill",
        "heart", "heart.fill", "bookmark", "bookmark.fill"
    ]
    
    private let colors = [
        "#007AFF", "#34C759", "#FF9500", "#FF3B30",
        "#AF52DE", "#FF2D92", "#5AC8FA", "#FFCC00",
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("List Details") {
                    TextField("List Name", text: $listName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Description (Optional)", text: $listDescription, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section("List Type") {
                    Toggle("Smart List", isOn: $isSmartList)
                        .tint(AppTheme.Colors.accent)
                    
                    if isSmartList {
                        Text("Smart lists automatically organize reminders based on rules and conditions.")
                            .font(AppTheme.Typography.caption1)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                Section("Appearance") {
                    iconSelectionView
                    colorSelectionView
                }
            }
            .navigationTitle("Create List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createList()
                    }
                    .disabled(listName.isEmpty || isCreating)
                }
            }
            .overlay {
                if isCreating {
                    ProgressView("Creating...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
        }
    }
    
    private var iconSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon")
                .font(AppTheme.Typography.body)
                .fontWeight(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                ForEach(icons, id: \.self) { icon in
                    Button {
                        selectedIcon = icon
                    } label: {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(selectedIcon == icon ? .white : .primary)
                            .frame(width: 40, height: 40)
                            .background(
                                selectedIcon == icon ? (Color(hex: selectedColor) ?? .blue) : Color.gray.opacity(0.2),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                }
            }
        }
    }
    
    private var colorSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(AppTheme.Typography.body)
                .fontWeight(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(colors, id: \.self) { color in
                    Button {
                        selectedColor = color
                    } label: {
                        Circle()
                            .fill(Color(hex: color) ?? .blue)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? .primary : Color.clear, lineWidth: 2)
                            )
                    }
                }
            }
        }
    }
    
    private func createList() {
        guard !listName.isEmpty else { return }
        
        isCreating = true
        
        Task {
            let list = ReminderList(
                name: listName,
                isSmart: isSmartList
            )
            
            // Add to workspace if it's a regular list
            if !isSmartList {
                // Create a shared list for the workspace
                let sharedList = SharedList(
                    list: list,
                    ownerID: collaborationManager.currentUserID ?? "",
                    ownerName: collaborationManager.currentUserName ?? ""
                )
                
                // Set sharing permissions
                sharedList.allowAddReminders = true
                sharedList.allowEditReminders = true
                sharedList.allowDeleteReminders = false
                sharedList.allowManageParticipants = false
                
                context.insert(sharedList)
                workspace.sharedLists?.append(sharedList)
            }
            
            context.insert(list)
            
            do {
                try context.save()
                
                await MainActor.run {
                    isCreating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    // Handle error silently in production
                }
            }
        }
    }
}

// Preview disabled - requires model context setup
// #Preview {
//     CreateListView(workspace: Workspace(name: "Sample Workspace", ownerID: "user123", ownerName: "John Doe"))
//         .modelContainer(for: [Workspace.self, ReminderList.self, SharedList.self])
// }
