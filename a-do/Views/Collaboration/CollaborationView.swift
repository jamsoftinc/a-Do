//
//  CollaborationView.swift
//  a-do
//
//  Collaboration and sharing interface
//

import SwiftUI
import SwiftData

struct CollaborationView: View {
    @Environment(\.modelContext) private var context
    @State private var collaborationManager = CollaborationManager.shared
    
    @Query private var workspaces: [Workspace]
    @Query private var sharedReminders: [SharedReminder]
    @Query private var shareParticipants: [ShareParticipant]
    
    @State private var selectedTab = 0
    @State private var showingCreateWorkspace = false
    @State private var showingInviteUser = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("View", selection: $selectedTab) {
                    Text("Workspaces").tag(0)
                    Text("Shared").tag(1)
                    Text("Invitations").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                TabView(selection: $selectedTab) {
                    workspacesTab
                        .tag(0)
                    
                    sharedRemindersTab
                        .tag(1)
                    
                    invitationsTab
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Collaboration")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if selectedTab == 0 {
                            showingCreateWorkspace = true
                        } else if selectedTab == 1 {
                            showingInviteUser = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateWorkspace) {
            CreateWorkspaceView()
        }
        .sheet(isPresented: $showingInviteUser) {
            InviteUserView()
        }
    }
    
    // MARK: - Workspaces Tab
    
    private var workspacesTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if workspaces.isEmpty {
                    EmptyWorkspacesView {
                        showingCreateWorkspace = true
                    }
                } else {
                    ForEach(workspaces) { workspace in
                        WorkspaceCard(workspace: workspace)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Shared Reminders Tab
    
    private var sharedRemindersTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if sharedReminders.isEmpty {
                    EmptySharedRemindersView {
                        showingInviteUser = true
                    }
                } else {
                    ForEach(sharedReminders) { sharedReminder in
                        SharedReminderCard(sharedReminder: sharedReminder)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Invitations Tab
    
    private var invitationsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Pending Invitations
                let pendingInvitations = shareParticipants.filter { $0.status == ShareStatus.pending }
                
                if !pendingInvitations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pending Invitations")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        ForEach(pendingInvitations) { invitation in
                            InvitationCard(invitation: invitation) { action in
                                handleInvitation(invitation, action: action)
                            }
                        }
                    }
                }
                
                // Sent Invitations
                let sentInvitations = shareParticipants.filter { $0.status != ShareStatus.pending }
                
                if !sentInvitations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sent Invitations")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        ForEach(sentInvitations) { invitation in
                            SentInvitationCard(invitation: invitation)
                        }
                    }
                }
                
                if pendingInvitations.isEmpty && sentInvitations.isEmpty {
                    EmptyInvitationsView()
                }
            }
            .padding()
        }
    }
    
    // MARK: - Actions
    
    private func handleInvitation(_ invitation: ShareParticipant, action: InvitationAction) {
        Task {
            switch action {
            case .accept:
                await collaborationManager.acceptInvitation(invitation, context: context)
            case .decline:
                await collaborationManager.declineInvitation(invitation, context: context)
            }
        }
    }
}

// MARK: - Supporting Views

struct WorkspaceCard: View {
    let workspace: Workspace
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workspace.name)
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text(workspace.workspaceDescription ?? "No description")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(workspace.members.count)")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.accent)
                        
                        Text("members")
                            .font(AppTheme.Typography.caption1)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                HStack {
                    Label("Created \(workspace.createdAt, style: .relative)", systemImage: "calendar")
                        .font(AppTheme.Typography.caption1)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Spacer()
                    
                    if workspace.ownerID == "current-user-id" { // TODO: Replace with actual current user ID
                        Label("Owner", systemImage: "crown")
                            .font(AppTheme.Typography.caption1)
                            .foregroundColor(AppTheme.Colors.accent)
                    }
                }
            }
        }
    }
}

struct SharedReminderCard: View {
    let sharedReminder: SharedReminder
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sharedReminder.shareTitle)
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        if !sharedReminder.shareMessage.isEmpty {
                            Text(sharedReminder.shareMessage)
                                .font(AppTheme.Typography.body)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: "person.2")
                            .foregroundColor(AppTheme.Colors.accent)
                        
                        Text("Shared")
                            .font(AppTheme.Typography.caption1)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                HStack {
                    Label("Shared by \(sharedReminder.ownerName)", systemImage: "person")
                        .font(AppTheme.Typography.caption1)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text(sharedReminder.sharedAt, style: .relative)
                        .font(AppTheme.Typography.caption1)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
    }
}

struct InvitationCard: View {
    let invitation: ShareParticipant
    let onAction: (InvitationAction) -> Void
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Invitation from \(invitation.name)")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text(invitation.email)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: invitation.permission.icon)
                            .foregroundColor(invitation.permission.color)
                        
                        Text(invitation.permission.displayName)
                            .font(AppTheme.Typography.caption1)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                Text("Invited \(invitation.invitedAt, style: .relative)")
                    .font(AppTheme.Typography.caption1)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack(spacing: 12) {
                    Button("Accept") {
                        onAction(.accept)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.accent)
                    
                    Button("Decline") {
                        onAction(.decline)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.Colors.textSecondary)
                    
                    Spacer()
                }
            }
        }
    }
}

struct SentInvitationCard: View {
    let invitation: ShareParticipant
    
    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(invitation.name)
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(invitation.email)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("Sent \(invitation.invitedAt, style: .relative)")
                        .font(AppTheme.Typography.caption1)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(invitation.status.displayName)
                        .font(AppTheme.Typography.caption1)
                        .foregroundColor(invitation.status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(invitation.status.color.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text(invitation.permission.displayName)
                        .font(AppTheme.Typography.caption2)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Empty State Views

struct EmptyWorkspacesView: View {
    let onCreate: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text("No Workspaces")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Create a workspace to collaborate with others on reminders and tasks.")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Create Workspace") {
                onCreate()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.accent)
        }
        .padding()
    }
}

struct EmptySharedRemindersView: View {
    let onInvite: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shared.with.you")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text("No Shared Reminders")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Share reminders with others or accept invitations to see shared content here.")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Invite Someone") {
                onInvite()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.accent)
        }
        .padding()
    }
}

struct EmptyInvitationsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text("No Invitations")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Invitations to collaborate will appear here.")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Create Views (Placeholders)

struct CreateWorkspaceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Create Workspace - Coming Soon")
                    .font(AppTheme.Typography.headline)
                // TODO: Implement workspace creation form
            }
            .navigationTitle("Create Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InviteUserView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Invite User - Coming Soon")
                    .font(AppTheme.Typography.headline)
                // TODO: Implement user invitation form
            }
            .navigationTitle("Invite User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum InvitationAction {
    case accept
    case decline
}

// MARK: - Extensions

extension SharingPermission {
    var icon: String {
        switch self {
        case .view: return "eye"
        case .edit: return "pencil"
        case .admin: return "crown"
        }
    }
    
    var color: Color {
        switch self {
        case .view: return .blue
        case .edit: return .orange
        case .admin: return .purple
        }
    }
}

extension ShareStatus {
    var color: Color {
        switch self {
        case .pending: return .orange
        case .accepted: return .green
        case .declined: return .red
        case .revoked: return .gray
        }
    }
}

#Preview {
    CollaborationView()
        .modelContainer(for: [Workspace.self, SharedReminder.self, ShareParticipant.self])
}
