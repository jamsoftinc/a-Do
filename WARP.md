# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is **a-do**, an iOS reminder application built with SwiftUI and SwiftData. It features integration with Apple Reminders, CloudKit sync, location-based reminders, habits tracking, and widgets.

## Common Development Commands

### Build and Run
```bash
# Build the project
xcodebuild -project a-do.xcodeproj -scheme a-do -configuration Debug build

# Build for release
xcodebuild -project a-do.xcodeproj -scheme a-do -configuration Release build

# Clean build folder
xcodebuild -project a-do.xcodeproj -scheme a-do clean
```

### Testing
```bash
# Run tests
xcodebuild test -project a-do.xcodeproj -scheme a-do -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'

# Run tests on specific device
xcodebuild test -project a-do.xcodeproj -scheme a-do -destination 'platform=iOS Simulator,name=iPad Air (5th generation),OS=latest'
```

### Widget Development
```bash
# The project includes widget extensions in a-do_Widget/
# Widgets are built automatically with the main target
# Test widgets using the Widget simulator or on device
```

## Architecture Overview

### Core Architecture Pattern
- **MVVM with SwiftUI**: Views use `@State` and `@Observable` view models
- **SwiftData**: Primary data persistence layer with CloudKit integration
- **Manager Pattern**: Singleton managers handle specific domains (RemindersManager, LocationManager, etc.)
- **Progressive Container Loading**: Fault-tolerant SwiftData container initialization in `AppContainer.swift`

### Key Components

#### Data Layer
- **Models/**: SwiftData models with validation and security utilities
  - `ReminderModels.swift`: Core reminder, list, tag, and location trigger models
  - `HabitModels.swift`: Habit tracking models
  - `AppSettings.swift`: User preferences and settings
- **SwiftDataUtils.swift**: Diagnostic utilities for container creation and model validation

#### Manager Layer (Managers/)
- **RemindersManager**: Apple Reminders integration and import/export
- **CloudKitManager**: iCloud sync coordination
- **LocationManager**: Core Location integration for location-based reminders
- **NotificationManager**: Local notification scheduling and management
- **AppleRemindersSyncManager**: Bidirectional sync with Apple Reminders
- **CalendarManager**: EventKit integration for calendar events
- **AIManager**: AI-powered reminder categorization and suggestions

#### View Layer Architecture
- **Views/Home/**: Main interface with adaptive layout for iPhone/iPad
- **Views/Components/**: Reusable UI components with consistent styling
- **Views/ReminderForm/**: Complex form handling with validation
- **Shared/AppRouter.swift**: Deep link navigation and URL scheme handling

#### Styling System
- **AppTheme.swift**: Centralized design system with colors, typography, and spacing
- **Color+Hex.swift**: Hex color validation and conversion utilities
- Uses `.rounded` design language throughout the app

### Data Flow
1. **App Launch**: `ADoApp.swift` → `RootView` → Progressive sync initialization
2. **Container Creation**: `AppContainer` with diagnostic fallback strategies
3. **Sync Process**: Multi-stage sync (Data → Apple Reminders → CloudKit → Calendar)
4. **Navigation**: `AppRouter` handles deep links and inter-app communication

### Key Features Integration

#### Location-Based Reminders
- Requires location permissions (see `LocationUsageDescription.md`)
- Uses `LocationTrigger` model with coordinate validation
- Background monitoring for arrival/departure events

#### Apple Integrations
- **Apple Reminders**: Full bidirectional sync with import/export
- **EventKit**: Calendar integration for due date coordination
- **CloudKit**: Data sync across devices with account status monitoring
- **App Intents**: Siri shortcuts for reminder creation

#### Widget System
- **WidgetKit**: Home screen widgets showing today's reminders
- **App Groups**: Shared data between main app and widgets via `group.JAMSoft.a-do`
- **AppGroupDefaults**: Centralized UserDefaults management for widget communication

## Development Guidelines

### SwiftData Best Practices
- Use `AppContainer.shared.getContainer()` for consistent container access
- Models include validation in initializers (coordinate clamping, string trimming)
- Diagnostic utilities available for debugging container issues in development

### Manager Dependencies
- Managers are singletons accessed via `.shared`
- Most managers require `@MainActor` for UI coordination
- Use `Task { @MainActor in }` when calling from background contexts

### Security and Validation
- `SecurityUtils.validateHexColor()` for user-provided color values
- Input trimming and validation in all model initializers
- Location coordinates are clamped to valid Earth ranges

### Widget Development
- Widgets share data via App Group container
- Use `AppGroupDefaults` for simple data sharing
- Complex data requires SwiftData queries with shared container

### Testing Considerations
- Use Debug builds for full diagnostic logging
- `#if DEBUG` blocks contain additional validation and testing utilities
- `AppContainer.testContainerCreation()` available for debugging data issues

### Performance Optimization
- Cached filtered reminders in `HomeView` to prevent expensive recomputation
- Background task management for sync operations
- Lazy loading patterns in complex list views

## URL Schemes and Deep Links

The app handles several URL schemes:
- `a-do://smart/today` - Open today's reminders
- `a-do://habits` - Open habits view  
- `a-do://tag/{tagName}` - Filter by tag
- `a-do://priority/{level}` - Filter by priority level
- `mobilenotes://` - Handle Notes app callbacks

## Entitlements and Capabilities

Required capabilities:
- CloudKit (Production environment)
- Push Notifications (Time-sensitive)
- App Groups (`group.JAMSoft.a-do`)
- Location Services (for location-based reminders)
- EventKit access (for calendar integration)

## File Structure Notes

- Main target: `a-do/`
- Widget extension: `a-do_Widget/`
- Shared models work across both targets via careful import management
- `Shared/` folder contains cross-target utilities

## Debugging Common Issues

### SwiftData Container Issues
- Check `AppContainer` logs for diagnostic information
- Use `.testContainerCreation()` in debug builds
- Progressive fallback system handles most model conflicts

### Sync Problems
- Monitor `SyncProgressManager` for sync stage failures  
- CloudKit account status affects sync availability
- Apple Reminders permission required for bidirectional sync

### Widget Data Issues
- Verify App Group configuration matches entitlements
- Check `AppGroupDefaults` for data sharing problems
- Widgets may need container recreation after model changes