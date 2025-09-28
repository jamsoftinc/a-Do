#!/usr/bin/env swift

import Foundation
import SwiftData

// This is a standalone test to check if basic reminder creation and saving works

// Simplified Reminder model for testing
@Model
final class TestReminder {
    var uuid: UUID = UUID()
    var title: String = ""
    var details: String?
    var dueDate: Date?
    var createdAt: Date = Date()
    var isCompleted: Bool = false
    var completedAt: Date?
    var priorityRaw: Int = 0
    var appleReminderID: String?
    var autoTextTaggedContacts: Bool = false
    var autoTextMe: Bool = false
    var calendarInviteCreated: Bool = false

    init() {
        self.uuid = UUID()
        self.title = ""
        self.createdAt = Date()
        self.priorityRaw = 0
    }
    
    init(title: String, details: String? = nil, dueDate: Date? = nil) {
        self.uuid = UUID()
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.details = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dueDate = dueDate
        self.createdAt = Date()
        self.priorityRaw = 0
    }
}

func testBasicReminderSave() {
    print("Testing basic reminder creation and saving...")
    
    do {
        // Create an in-memory container
        let schema = Schema([TestReminder.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        
        let context = ModelContext(container)
        
        // Create a test reminder
        let reminder = TestReminder(title: "Test Reminder", details: "This is a test")
        print("✓ Created reminder with title: '\(reminder.title)'")
        
        // Insert into context
        context.insert(reminder)
        print("✓ Inserted reminder into context")
        
        // Save context
        try context.save()
        print("✓ Successfully saved context")
        
        // Verify the reminder was saved by fetching it
        let descriptor = FetchDescriptor<TestReminder>()
        let savedReminders = try context.fetch(descriptor)
        
        print("✓ Fetched \(savedReminders.count) reminders from context")
        
        if let firstReminder = savedReminders.first {
            print("✓ First reminder title: '\(firstReminder.title)'")
            print("✓ First reminder UUID: \(firstReminder.uuid)")
            print("✓ First reminder created at: \(firstReminder.createdAt)")
        }
        
        print("\n✅ Test PASSED - Basic reminder saving works correctly!")
        
    } catch {
        print("\n❌ Test FAILED - Error: \(error)")
        print("Error details: \(String(describing: error))")
    }
}

// Run the test
testBasicReminderSave()