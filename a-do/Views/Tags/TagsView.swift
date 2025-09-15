import SwiftUI
import SwiftData
import os

struct TagsView: View {
    @Environment(\.modelContext) private var context
    @State private var tags: [Tag] = []
    @State private var newName: String = ""
    @State private var selectedColor: String = Tag.defaultColors.first ?? "#7C4DFF"

    var body: some View {
        Form {
            Section("Create Tag") {
                TextField("Name", text: $newName)
                ColorSwatches(selected: $selectedColor)
                Button("Add") { addTag() }.disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Section("Tags") {
                ForEach(tags) { tag in
                    HStack {
                        Circle().fill(Color(hex: tag.colorHex) ?? .purple).frame(width: 16, height: 16)
                        Text(tag.name)
                        Spacer()
                        Button(role: .destructive) { delete(tag) } label: { Image(systemName: "trash") }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Tags")
    }

    private func addTag() {
        let tag = Tag(name: newName, colorHex: selectedColor)
        context.insert(tag)
                    do { try context.save() } catch { Logger(subsystem: "a-do", category: "Tags").error("Save failed: \(String(describing: error))") }
        newName = ""
    }

    private func delete(_ tag: Tag) {
        context.delete(tag)
                    do { try context.save() } catch { Logger(subsystem: "a-do", category: "Tags").error("Delete failed: \(String(describing: error))") }
    }
}

private struct ColorSwatches: View {
    @Binding var selected: String
    var body: some View {
        FlowLayout(alignment: .leading, spacing: 8) {
            ForEach(Tag.defaultColors, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex) ?? .purple)
                    .frame(width: selected == hex ? 28 : 24, height: selected == hex ? 28 : 24)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: selected == hex ? 3 : 1)
                    )
                    .onTapGesture { selected = hex }
            }
        }
    }
}


