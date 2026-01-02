import SwiftUI
import SwiftData

struct WorkspaceDetailView: View {
    let workspace: Workspace
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var collaborationManager = CollaborationManager.shared
    
    @State private var showingInviteUser = false
    @State private var showingEditWorkspace = false
    @State private var showingMembers = false
    @State private var showingShareReminder = false
    @State private var showingCreateList = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Workspace Header
                    workspaceHeaderSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Members Section
                    membersSection
                    
                    // Shared Lists Section
                    sharedListsSection
                    
                    // Recent Activity Section
                    recentActivitySection
                }
                .padding()
            }
            .navigationTitle(workspace.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit Workspace") {
                            showingEditWorkspace = true
                        }
                        
                        Button("Invite Members") {
                            showingInviteUser = true
                        }
                        
                        Button("Manage Members") {
                            showingMembers = true
                        }
                        
                        if isOwner {
                            Button("Delete Workspace", role: .destructive) {
                                deleteWorkspace()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingInviteUser) {
            InviteUserView(workspace: workspace)
        }
        .sheet(isPresented: $showingEditWorkspace) {
            EditWorkspaceView(workspace: workspace)
        }
        .sheet(isPresented: $showingMembers) {
            WorkspaceMembersView(workspace: workspace)
        }
        .sheet(isPresented: $showingShareReminder) {
            ShareReminderView()
        }
        .sheet(isPresented: $showingCreateList) {
            CreateListView(workspace: workspace)
        }
    }
    
    // MARK: - Workspace Header
    
    private var workspaceHeaderSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(workspace.name)
                            .font(AppTheme.Typography.title2)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        let description = workspace.workspaceDescription
                        if !description.isEmpty {
                            Text(description)
                                .font(AppTheme.Typography.body)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        HStack {
                            Label("Created \(workspace.createdAt, style: .date)", systemImage: "calendar")
                                .font(AppTheme.Typography.caption1)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            Spacer()
                            
                            if isOwner {
                                Label("Owner", systemImage: "crown.fill")
                                    .font(AppTheme.Typography.caption1)
                                    .foregroundColor(AppTheme.Colors.accent)
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                // Stats
                HStack(spacing: 20) {
                    WorkspaceStatItem(title: "Members", value: "\(workspace.members?.count ?? 0)", icon: "person.2")
                    WorkspaceStatItem(title: "Lists", value: "\(workspace.sharedLists?.count ?? 0)", icon: "list.bullet")
                    WorkspaceStatItem(title: "Reminders", value: "\(workspace.sharedReminders?.count ?? 0)", icon: "bell")
                }
            }
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionButton(
                    title: "Invite Members",
                    icon: "person.badge.plus",
                    color: .blue
                ) {
                    showingInviteUser = true
                }
                
                QuickActionButton(
                    title: "Create List",
                    icon: "list.bullet.rectangle",
                    color: .green
                ) {
                    showingCreateList = true
                }
                
                QuickActionButton(
                    title: "Share Reminder",
                    icon: "square.and.arrow.up",
                    color: .orange
                ) {
                    showingShareReminder = true
                }
                
                QuickActionButton(
                    title: "Settings",
                    icon: "gear",
                    color: .gray
                ) {
                    showingEditWorkspace = true
                }
            }
        }
    }
    
    // MARK: - Members Section
    
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Members")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button("View All") {
                    showingMembers = true
                }
                .font(AppTheme.Typography.caption1)
                .foregroundColor(AppTheme.Colors.accent)
            }
            
            if workspace.members?.isEmpty ?? true {
                Text("No members yet")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach((workspace.members ?? []).prefix(3)) { member in
                        MemberRowView(member: member)
                    }
                    
                    if (workspace.members?.count ?? 0) > 3 {
                        Text("+ \((workspace.members?.count ?? 0) - 3) more members")
                            .font(AppTheme.Typography.caption1)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }
    
    // MARK: - Shared Lists Section
    
    private var sharedListsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shared Lists")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            if workspace.sharedLists?.isEmpty ?? true {
                Text("No shared lists yet")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(workspace.sharedLists ?? []) { list in
                        SharedListRowView(list: list)
                    }
                }
            }
        }
    }
    
    // MARK: - Recent Activity Section
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Activity tracking coming soon")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        }
    }
    
    // MARK: - Computed Properties
    
    private var isOwner: Bool {
        workspace.ownerID == SecurityUtils.getCurrentUserID()
    }
    
    // MARK: - Actions
    
    private func deleteWorkspace() {
        // Workspace deletion functionality
        // Delete workspace
    }
}

// MARK: - Supporting Views

struct WorkspaceStatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AppTheme.Colors.accent)
            
            Text(value)
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(title)
                .font(AppTheme.Typography.caption1)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(AppTheme.Typography.caption1)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct MemberRowView: View {
    let member: WorkspaceMember
    
    var body: some View {
        HStack {
            Circle()
                .fill(AppTheme.Colors.accent)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(member.name.prefix(1).uppercased())
                        .font(AppTheme.Typography.caption1)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(member.email)
                    .font(AppTheme.Typography.caption1)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Text(member.role.displayName)
                .font(AppTheme.Typography.caption1)
                .foregroundColor(member.role.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(member.role.color.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }
}

struct SharedListRowView: View {
    let list: SharedList

    var body: some View {
        HStack {
            Image(systemName: "list.bullet.rectangle")
                .foregroundColor(AppTheme.Colors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(list.list?.name ?? "Untitled List")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                let reminderCount = list.list?.reminders?.count ?? 0

                Text("\(reminderCount) reminders")
                    .font(AppTheme.Typography.caption1)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Text(list.allowEditReminders ? "Can Edit" : "View Only")
                .font(AppTheme.Typography.caption1)
                .foregroundColor(list.allowEditReminders ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((list.allowEditReminders ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary).opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let workspace = Workspace(name: "Sample Team", ownerID: "user123", ownerName: "John Doe")
    workspace.workspaceDescription = "Sample workspace for collaboration"
    
    return WorkspaceDetailView(workspace: workspace)
        .modelContainer(for: [Workspace.self, WorkspaceMember.self, SharedList.self])
}

