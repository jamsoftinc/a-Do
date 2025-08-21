# Thread Safety Crash Fix - libswiftCore Assertion Failure

## Problem
The app was crashing with:
- `libswiftCore.dylib _assertionFailure(_:_:file:line:flags:)`
- Happening in `AppContainer.container.getter`
- Called from `RootView.initializeContainer()`

This is a MainActor isolation violation - trying to access a `@MainActor` property from a non-MainActor context.

## Root Cause
The `AppContainer.container` was marked as `@MainActor` but was being accessed from an async context that wasn't guaranteed to be on the MainActor. This causes a runtime assertion failure in Swift's concurrency checking.

## Solution: Thread-Safe Container

Created `SafeAppContainer` that:
1. **Removes MainActor requirements**: No actor isolation, can be accessed from any thread
2. **Uses NSLock**: Thread-safe access to the container instance
3. **Lazy initialization**: Container is only created when first accessed
4. **Singleton pattern**: Ensures only one container instance exists

### Implementation Details

```swift
final class SafeAppContainer {
    static let shared = SafeAppContainer()
    
    private var _container: ModelContainer?
    private let containerLock = NSLock()
    
    func getContainer() -> ModelContainer {
        containerLock.lock()
        defer { containerLock.unlock() }
        
        // Thread-safe lazy initialization
        if let existingContainer = _container {
            return existingContainer
        }
        
        // Create container...
    }
}
```

### Updated References

1. **ADoApp.swift**: 
   ```swift
   modelContainer = SafeAppContainer.shared.getContainer()
   ```

2. **ReminderShortcuts.swift**:
   ```swift
   let container = SafeAppContainer.shared.getContainer()
   ```

3. **a-do_Widget.swift**:
   ```swift
   let container = SafeAppContainer.shared.getContainer()
   ```

## Benefits

1. **No MainActor violations**: Can be safely accessed from any thread
2. **Thread-safe**: NSLock ensures no race conditions
3. **Performance**: Lock is only held during initialization check
4. **Simplicity**: No complex async/await or MainActor.run needed

## Testing

The crash should now be completely resolved. The app can:
- Initialize on any thread
- Access the container from widgets, app intents, or main app
- Handle concurrent access safely

This fix addresses the core threading issue that was causing the assertion failure.
