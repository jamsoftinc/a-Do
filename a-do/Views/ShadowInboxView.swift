import SwiftUI
import SwiftData

struct ShadowInboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShadowTask.createdAt, order: .reverse) private var shadowTasks: [ShadowTask]
    @State private var newThought: String = ""
    @State private var isPromoting: Bool = false
    @State private var promotionResult: String?
    
    var body: some View {
        NavigationStack {
            VStack {
                // Input Area
                HStack {
                    TextField("Dump a thought...", text: $newThought)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit {
                            addThought()
                        }
                    
                    Button(action: addThought) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(newThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                
                // List of Thoughts
                List {
                    if shadowTasks.isEmpty {
                        ContentUnavailableView("Shadow Inbox Empty", systemImage: "tray", description: Text("Dump your unstructured thoughts here."))
                    } else {
                        ForEach(shadowTasks) { task in
                            HStack {
                                Text(task.content)
                                Spacer()
                                if task.isPromoted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Button("Promote") {
                                        promoteSingle(task)
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                }
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
                
                // Auto-Promote Button
                Button(action: autoPromoteAll) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Auto-Promote All")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .disabled(shadowTasks.filter { !$0.isPromoted }.isEmpty)
            }
            .navigationTitle("Shadow Inbox")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .alert("Promotion Result", isPresented: $isPromoting) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(promotionResult ?? "Processing...")
            }
        }
    }

    private func addThought() {
        guard !newThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let newTask = ShadowTask(content: newThought)
        modelContext.insert(newTask)
        try? modelContext.save()
        newThought = ""
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(shadowTasks[index])
            }
            try? modelContext.save()
        }
    }
    
    private func promoteSingle(_ task: ShadowTask) {
        // Promote immediately using rule-based parsing.
        let reminder = ShadowTaskPromoter.promote(task)
        modelContext.insert(reminder)
        task.promote(to: reminder.uuid)
        try? modelContext.save() // Ensure ID linkage is saved
    }

    private func autoPromoteAll() {
        var count = 0
        for task in shadowTasks where !task.isPromoted {
            let reminder = ShadowTaskPromoter.promote(task)
            modelContext.insert(reminder)
            task.promote(to: reminder.uuid)
            count += 1
        }
        try? modelContext.save()
        isPromoting = true
        promotionResult = "Promoted \(count) thoughts to structured tasks."
    }
}
