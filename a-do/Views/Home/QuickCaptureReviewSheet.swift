import SwiftUI

struct QuickCaptureReviewSheet: View {
    @Binding var drafts: [QuickCaptureDraft]
    let isSaving: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Review Captured Tasks") {
                    ForEach($drafts) { $draft in
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Title", text: $draft.title)
                                .textInputAutocapitalization(.sentences)

                            TextField("Details", text: $draft.details, axis: .vertical)
                                .lineLimit(2...4)

                            if draft.dueDate != nil {
                                DatePicker(
                                    "Due Date",
                                    selection: dueDateBinding(for: $draft),
                                    displayedComponents: [.date, .hourAndMinute]
                                )

                                Button("Clear Due Date", role: .destructive) {
                                    draft.dueDate = nil
                                }
                                .font(.caption)
                            } else {
                                Button("Add Due Date") {
                                    draft.dueDate = Date()
                                }
                                .font(.caption.weight(.medium))
                            }

                            Picker("Priority", selection: $draft.priority) {
                                ForEach(Priority.allCases) { priority in
                                    Text(priority.title).tag(priority)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        drafts.remove(atOffsets: offsets)
                    }
                }
            }
            .navigationTitle("Review Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Create") {
                        onConfirm()
                    }
                    .disabled(isSaving || drafts.isEmpty || drafts.allSatisfy { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                }
            }
        }
    }

    private func dueDateBinding(for draft: Binding<QuickCaptureDraft>) -> Binding<Date> {
        Binding<Date>(
            get: {
                draft.wrappedValue.dueDate ?? Date()
            },
            set: { newValue in
                draft.wrappedValue.dueDate = newValue
            }
        )
    }
}
