# Closure Capture Semantics Fix

## Problem
Swift compiler error: "Reference to property 'quickDueDate' in closure requires explicit use of 'self' to make capture semantics explicit"

## Root Cause
In Swift, when referencing instance properties from within closures, the compiler requires explicit `self` to make it clear that the closure is capturing the instance. This helps prevent retain cycles and makes the code more explicit about what's being captured.

## Files Fixed

### 1. ReminderViewModels.swift
**Location**: Line 21 in logging closure
**Before**:
```swift
Logger(subsystem: "a-do", category: "Reminders").info("Quick reminder saved: '\(safeTitle)' with ID: \(reminder.id), due: \(quickDueDate?.description ?? "none")")
```

**After**:
```swift
Logger(subsystem: "a-do", category: "Reminders").info("Quick reminder saved: '\(safeTitle)' with ID: \(reminder.id), due: \(self.quickDueDate?.description ?? "none")")
```

### 2. HomeView.swift
**Location**: DatePicker Binding closures
**Before**:
```swift
DatePicker("Due Date", selection: Binding(
    get: { viewModel.quickDueDate ?? Date() },
    set: { viewModel.quickDueDate = $0 }
), displayedComponents: [.date, .hourAndMinute])
```

**After**:
```swift
DatePicker("Due Date", selection: Binding(
    get: { self.viewModel.quickDueDate ?? Date() },
    set: { self.viewModel.quickDueDate = $0 }
), displayedComponents: [.date, .hourAndMinute])
```

## Why This Fix Is Important

1. **Compiler Compliance**: Satisfies Swift's explicit capture semantics requirements
2. **Code Clarity**: Makes it obvious what's being captured by the closure
3. **Memory Safety**: Helps prevent potential retain cycles
4. **Best Practices**: Follows Swift's recommended patterns for closure captures

## Other Closure References

The other references to `viewModel.quickDueDate` in HomeView are in:
- Button tint modifiers (not in escaping closures)
- Conditional view rendering (not in closures)
- Button action closures that call methods (not direct property access)

These don't require explicit `self` because they're either:
- Non-escaping closures where implicit self is allowed
- Direct method calls rather than property access
- View modifier parameters that don't escape

## Status
✅ All closure capture semantic errors resolved
✅ Code now compiles without warnings
✅ Maintains the same functionality while being more explicit
