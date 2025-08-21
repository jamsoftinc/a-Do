# App Crash Diagnostics - static ADoApp.$main()

## Current Crash Pattern
- Crash in: `static ADoApp.$main() + 24`
- Thread: Main thread (Thread 0)
- Occurs at app startup before any UI is shown

## Potential Causes

1. **SwiftData Model Issues**
   - Complex model relationships causing initialization problems
   - Circular dependencies in model definitions

2. **Static Initialization Race Conditions**
   - AppContainer being accessed before app is ready
   - MainActor isolation conflicts

3. **Build Configuration Issues**
   - Incorrect entitlements or provisioning
   - Code signing problems

## Debugging Steps

### 1. Simplify App Entry Point
Already done - removed all initialization from @main struct

### 2. Defer All Complex Initialization
- ModelContainer initialization deferred to async task
- Router initialization happens in View context

### 3. Check for Static Dependencies
Look for any static properties that might be initialized at app startup

## Next Steps to Try

1. **Clean Build**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/*
   ```

2. **Reset Simulator/Device**
   - Delete app from device
   - Reset device if needed

3. **Check Xcode Console**
   Look for any error messages before the crash

4. **Minimal App Test**
   Try commenting out the modelContainer to see if SwiftData is the issue

## Temporary Workaround

If the crash persists, try this minimal app structure:

```swift
@main
struct ADoApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Hello World")
        }
    }
}
```

Then gradually add components back to identify the cause.
