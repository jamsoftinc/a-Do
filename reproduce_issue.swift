#!/usr/bin/env swift

import Foundation
import SwiftData

// Mock Reminder Model
@Model
final class Reminder {
    var uuid: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()
    var isCompleted: Bool = false
    
    init(title: String) {
        self.title = title
    }
}

@MainActor
func testReproduction() async {
    print("Starting reproduction test...")
    
    do {
        // Setup Container
        let schema = Schema([Reminder.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let mainContext = container.mainContext
        
        // 1. Create and Save Reminder on Main Context
        let reminder = Reminder(title: "Test Reminder")
        mainContext.insert(reminder)
        try mainContext.save()
        print("✓ Saved reminder: \(reminder.title)")
        
        // 2. Try to load from background context (mimicking MemorySafeDataLoader)
        let loadedIDs = await Task.detached {
            let backgroundContext = ModelContext(container)
            let descriptor = FetchDescriptor<Reminder>()
            let reminders = try! backgroundContext.fetch(descriptor)
            return reminders.map { $0.persistentModelID }
        }.value
        
        print("✓ Loaded \(loadedIDs.count) IDs from background context")
        
        // 3. Fetch object on Main Actor
        if let id = loadedIDs.first {
            if let loaded = mainContext.model(for: id) as? Reminder {
                print("✓ Successfully fetched reminder on main context: \(loaded.title)")
            } else {
                print("❌ Failed to fetch reminder on main context")
            }
        } else {
            print("❌ No IDs returned")
        }
        
    } catch {
        print("❌ Error: \(error)")
    }
}

// Run the test
// Note: We need a run loop or async entry point. 
// Since this is a script, we'll use a simplified approach.

let semaphore = DispatchSemaphore(value: 0)

Task { @MainActor in
    await testReproduction()
    semaphore.signal()
}

semaphore.wait()
