import SwiftUI

struct AppleNoteAttachmentView: View {
    let noteAttachment: AppleNoteAttachment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.blue)
                Text("Apple Note")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Open") {
                    NotesManager.shared.openNoteInNotesApp(noteIdentifier: noteAttachment.noteIdentifier)
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(noteAttachment.noteTitle.isEmpty ? "Untitled Note" : noteAttachment.noteTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(noteAttachment.noteContent)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                Text("Last modified: \(noteAttachment.lastModified, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

#Preview {
    AppleNoteAttachmentView(
        noteAttachment: AppleNoteAttachment(
            noteIdentifier: "test-123",
            noteTitle: "Sample Note",
            noteContent: "This is a sample note content that demonstrates how the attachment view looks.",
            lastModified: Date()
        )
    )
    .padding()
}

