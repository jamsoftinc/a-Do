# Static ADoApp.$main() Crash Fix

## Problem
The app was crashing in `static ADoApp.$main()` during app startup with offset +24. This crash occurs when SwiftUI's `@main` entry point encounters issues during static initialization.

## Root Causes

1. **Complex Initialization in App struct**: The App struct was directly initializing properties that accessed MainActor-isolated singletons.

2. **Cross-Actor Access**: AppRouter was accessing MainActor-isolated RealNotesManager.shared from potentially non-MainActor contexts.

3. **Static Initialization Order**: Multiple static properties being initialized during app startup could create race conditions.

## Solutions Applied

### 1. Simplified App Entry Point
Moved complex initialization out of the App struct into a separate RootView:

**Before:**
```swift
@main
struct ADoApp: App {
    @State private var router = AppRouter()  // Potential initialization issue
    
    var body: some Scene {
        WindowGroup {
            LaunchScreenWrapper {
                ContentView()
                    .modelContainer(AppContainer.shared.container)
                    // ... more modifiers
            }
        }
    }
}
```

**After:**
```swift
@main
struct ADoApp: App {
    init() {
        // Simple initialization only
        #if DEBUG
        print("🚀 a-do app starting...")
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()  // Deferred initialization
        }
    }
}

struct RootView: View {
    @State private var router = AppRouter()  // Initialized in View context
    
    var body: some View {
        LaunchScreenWrapper {
            ContentView()
                .modelContainer(AppContainer.shared.container)
                .environment(router)
                .onOpenURL { url in router.handle(url: url) }
                .task { router.checkGroupDeeplinkFlag() }
        }
    }
}
```

### 2. Fixed Cross-Actor Access in AppRouter
Wrapped MainActor-isolated calls in Task blocks:

**Before:**
```swift
if url.scheme == "mobilenotes" {
    _ = RealNotesManager.shared.handleNotesURL(url)  // Direct access to MainActor
}
```

**After:**
```swift
if url.scheme == "mobilenotes" {
    Task { @MainActor in
        _ = RealNotesManager.shared.handleNotesURL(url)  // Proper MainActor access
    }
}
```

## Benefits

1. **Clean App Initialization**: The `@main` entry point now has minimal initialization logic.

2. **Deferred Property Creation**: Complex properties are created in View context, not during static initialization.

3. **Actor Safety**: All MainActor-isolated resources are accessed properly.

4. **Better Error Isolation**: If initialization fails, it happens in a more debuggable context.

## Testing

After these changes:
1. Clean build folder (⌘+Shift+K)
2. Delete app from device
3. Build and run
4. Check console for "🚀 a-do app starting..." message
5. App should launch without the static $main crash

## Key Learnings

- Keep `@main` App structs simple with minimal initialization
- Defer complex property initialization to View contexts
- Always respect actor isolation boundaries
- Use Task blocks for cross-actor calls
