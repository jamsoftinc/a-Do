# AppContainer Initialization Crash Fix

## Problem
The app was crashing during initialization with the following stack trace:
- `ADoApp.init()` → `AppContainer.container.getter` → `closure #1 in AppContainer.container.getter`

This crash was occurring because the `sharedModelContainer` property in `ADoApp` was being initialized as a stored property, causing premature access to the AppContainer before the app was fully initialized.

## Root Cause
1. **Stored Property Initialization**: The `sharedModelContainer` was declared as:
   ```swift
   var sharedModelContainer: ModelContainer = AppContainer.shared.container
   ```
   This forces the container to be accessed during the app's init phase, which can happen on any thread.

2. **Thread Safety**: The AppContainer's static initialization could happen on a background thread during app launch, causing MainActor violations.

## Solution

### 1. Remove Stored Property in ADoApp
Changed from stored property to direct access in the view modifier:

**Before:**
```swift
@main
struct ADoApp: App {
    var sharedModelContainer: ModelContainer = AppContainer.shared.container
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            LaunchScreenWrapper {
                ContentView()
                    .modelContainer(sharedModelContainer)
                    // ...
            }
        }
    }
}
```

**After:**
```swift
@main
struct ADoApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            LaunchScreenWrapper {
                ContentView()
                    .modelContainer(AppContainer.shared.container)
                    // ...
            }
        }
    }
}
```

### 2. Improve Thread Safety in AppContainer
Applied `@MainActor` to specific properties instead of the entire class:

**Updated AppContainer:**
```swift
final class AppContainer {
    @MainActor
    static let shared = AppContainer()
    
    @MainActor
    private init() {}
    
    @MainActor
    lazy var container: ModelContainer = {
        // ... initialization code
    }()
}
```

## Benefits

1. **Deferred Initialization**: The container is now only accessed when the view is being constructed, ensuring proper app initialization order.

2. **MainActor Safety**: All container access is guaranteed to happen on the main thread.

3. **No Premature Access**: Removes the risk of accessing SwiftData before the app is ready.

4. **Cleaner Architecture**: Eliminates unnecessary stored property.

## Testing

After these changes:
1. Clean build folder (⌘+Shift+K)
2. Delete app from device
3. Build and run
4. The app should launch without the initialization crash

## Additional Notes

- The crash was specifically happening in the getter for the container property during app initialization
- This pattern ensures SwiftData is only initialized when actually needed by the UI
- The `@MainActor` annotations ensure all SwiftData operations happen on the main thread
