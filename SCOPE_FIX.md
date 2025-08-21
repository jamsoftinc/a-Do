# Variable Scope Fix - HomeView

## Problem
Swift compiler error: "Cannot find 'reminders' in scope" at line 109 in HomeView.swift

## Root Cause
When implementing the inbox system, I refactored the `reminders` computed property into two separate filtered arrays (`inboxReminders` and `todayReminders`), but missed updating one reference in the router handling code.

## Fix Applied

### Before
```swift
case .sendText(let rid):
    if let reminder = reminders.first(where: { $0.id == rid }) {
        Task { await composeAndSend(reminder: reminder) }
    }
```

### After
```swift
case .sendText(let rid):
    if let reminder = allReminders.first(where: { $0.id == rid }) {
        Task { await composeAndSend(reminder: reminder) }
    }
```

## Why This Fix Is Correct

1. **Comprehensive Search**: Using `allReminders` ensures we can find any reminder regardless of whether it's in the inbox or today's section
2. **Maintains Functionality**: The router can still find and handle reminders for the "send text" deep link feature
3. **Consistent with Refactor**: Aligns with the new data structure where `allReminders` contains all reminders, and the filtered arrays are for display purposes

## Variable Structure After Fix

```swift
// Raw data from SwiftData
@Query(sort: \Reminder.createdAt, order: .reverse) private var allReminders: [Reminder]

// Filtered for display
private var inboxReminders: [Reminder] { /* filtered subset */ }
private var todayReminders: [Reminder] { /* filtered subset */ }

// Usage:
// - allReminders: For searching/finding specific reminders
// - inboxReminders: For displaying inbox section
// - todayReminders: For displaying today's section
```

## Status
✅ Scope error resolved
✅ All reminder references properly scoped
✅ Router functionality maintained
✅ Inbox system fully functional
