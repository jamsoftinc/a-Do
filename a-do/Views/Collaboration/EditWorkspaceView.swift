import SwiftUI
import SwiftData

struct EditWorkspaceView: View {
    let workspace: Workspace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var workspaceName: String
    @State private var workspaceDescription: String
    @State private var isPublic: Bool
    
    init(workspace: Workspace) {
        self.workspace = workspace
        self._workspaceName = State(initialValue: workspace.name)
        self._workspaceDescription = State(initialValue: workspace.workspaceDescription)
        self._isPublic = State(initialValue: workspace.isPublic)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Workspace Details") {
                    TextField("Workspace Name", text: $workspaceName)
                    TextField("Description (Optional)", text: $workspaceDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Settings") {
                    Toggle("Public Workspace", isOn: $isPublic)
                }
                
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(workspaceName.isEmpty ? "Workspace Name" : workspaceName)
                            .font(.headline)
                        
                        Text(workspaceDescription.isEmpty ? "No description" : workspaceDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: isPublic ? "globe" : "lock.fill")
                            Text(isPublic ? "Public" : "Private")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .navigationTitle("Edit Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveWorkspace()
                    }
                    .disabled(workspaceName.isEmpty)
                }
            }
        }
    }
    
    private func saveWorkspace() {
        workspace.name = workspaceName
        workspace.workspaceDescription = workspaceDescription
        workspace.isPublic = isPublic
        workspace.updatedAt = Date()
        
        do {
            try context.save()
            dismiss()
        } catch {
            // Handle error silently in production
        }
    }
}
