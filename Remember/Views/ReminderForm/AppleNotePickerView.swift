import SwiftUI
import SwiftData

struct AppleNotePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedNote: AppleNoteAttachment?
    
    @State private var notes: [Note] = []
    @State private var isLoading = true
    @State private var showCreateNote = false
    @State private var newNoteTitle = ""
    @State private var newNoteContent = ""
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading notes...")
                } else if notes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "note.text")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No Notes Available")
                            .font(.headline)
                        
                        Text("You can create a new note or grant access to your existing notes.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Create New Note") {
                            showCreateNote = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List {
                        Section("Create New") {
                            Button("Create New Note") {
                                showCreateNote = true
                            }
                            .foregroundColor(.blue)
                        }
                        
                        Section("Existing Notes") {
                            ForEach(notes) { note in
                                Button {
                                    selectedNote = NotesManager.shared.createAppleNoteAttachment(from: note)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(note.title.isEmpty ? "Untitled Note" : note.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text(note.content)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                        
                                        Text("Modified: \(note.modificationDate, style: .relative)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Attach Apple Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadNotes()
        }
        .sheet(isPresented: $showCreateNote) {
            CreateNoteView { note in
                if let note = note {
                    selectedNote = NotesManager.shared.createAppleNoteAttachment(from: note)
                    dismiss()
                }
            }
        }
    }
    
    private func loadNotes() async {
        isLoading = true
        defer { isLoading = false }
        
        // Request authorization first
        let authorized = await NotesManager.shared.requestAuthorization()
        if authorized {
            notes = await NotesManager.shared.fetchNotes()
        }
    }
}

struct CreateNoteView: View {
    @Environment(\.dismiss) private var dismiss
    let onNoteCreated: (Note?) -> Void
    
    @State private var title = ""
    @State private var content = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Note Details") {
                    TextField("Title", text: $title)
                    TextField("Content", text: $content, axis: .vertical)
                        .lineLimit(5...10)
                }
            }
            .navigationTitle("Create Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createNote()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createNote() {
        isCreating = true
        
        Task {
            let note = await NotesManager.shared.createNote(
                title: title.trimmingCharacters(in: .whitespaces),
                content: content.trimmingCharacters(in: .whitespaces)
            )
            
            await MainActor.run {
                isCreating = false
                onNoteCreated(note)
            }
        }
    }
}

#Preview {
    AppleNotePickerView(selectedNote: .constant(nil))
}

