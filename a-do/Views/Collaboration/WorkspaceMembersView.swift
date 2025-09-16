import SwiftUI
import SwiftData

struct WorkspaceMembersView: View {
    let workspace: Workspace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var collaborationManager = CollaborationManager.shared
    
    @State private var showingInviteUser = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(workspace.members ?? []) { member in
                    MemberDetailRowView(member: member, workspace: workspace)
                }
            }
            .navigationTitle("Members (\(workspace.members?.count ?? 0))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Invite") {
                        showingInviteUser = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingInviteUser) {
            InviteUserView(workspace: workspace)
        }
    }
}

struct MemberDetailRowView: View {
    let member: WorkspaceMember
    let workspace: Workspace
    @Environment(\.modelContext) private var context
    
    var body: some View {
        HStack {
            Circle()
                .fill(AppTheme.Colors.accent)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(member.name.prefix(1).uppercased())
                        .font(AppTheme.Typography.body)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(member.email)
                    .font(AppTheme.Typography.caption1)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text("Joined \(member.joinedAt, style: .date)")
                    .font(AppTheme.Typography.caption2)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(member.role.displayName)
                    .font(AppTheme.Typography.caption1)
                    .foregroundColor(member.role.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(member.role.color.opacity(0.1))
                    .cornerRadius(8)
                
                Text(member.status.displayName)
                    .font(AppTheme.Typography.caption2)
                    .foregroundColor(member.status.color)
            }
        }
        .swipeActions(edge: .trailing) {
            if canManageMember {
                Button("Remove", role: .destructive) {
                    removeMember()
                }
                
                Button("Change Role") {
                    // Role change functionality
                }
                .tint(.blue)
            }
        }
    }
    
    private var canManageMember: Bool {
        // Only owner can manage members, and owner can't remove themselves
        workspace.ownerID == SecurityUtils.getCurrentUserID() && member.userID != workspace.ownerID
    }
    
    private func removeMember() {
        workspace.members?.removeAll { $0.id == member.id }
        
        do {
            try context.save()
        } catch {
            // Handle error silently in production
        }
    }
}

#Preview {
    // Explicitly type the models used in preview to avoid type inference issues
    let workspace: Workspace = Workspace(name: "Sample Team", ownerID: "user123", ownerName: "John Doe")

    // Add some sample members with explicit type annotations
    let member1: WorkspaceMember = WorkspaceMember(
        userID: "user123",
        email: "john@example.com",
        name: "John Doe",
        role: .owner,
        workspace: workspace
    )
    let member2: WorkspaceMember = WorkspaceMember(
        userID: "user456",
        email: "jane@example.com",
        name: "Jane Smith",
        role: .member,
        workspace: workspace
    )

    // Explicitly type the array to disambiguate the expression
    workspace.members = [member1, member2]

    return WorkspaceMembersView(workspace: workspace)
        .modelContainer(for: [Workspace.self, WorkspaceMember.self])
}
