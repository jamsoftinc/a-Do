# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**a-do** is an iOS reminder application built with SwiftUI and SwiftData. The app features comprehensive Apple ecosystem integration (Reminders, Calendar, CloudKit), location-based triggers, habit tracking, widgets, and an advanced AI/ML behavioral learning system.

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
# Run tests (update device name/OS version as needed)
xcodebuild test -project a-do.xcodeproj -scheme a-do -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'

# Run tests on iPad
xcodebuild test -project a-do.xcodeproj -scheme a-do -destination 'platform=iOS Simulator,name=iPad Air (5th generation),OS=latest'
```

## Architecture Overview

### Core Pattern: MVVM + Manager Singletons

**Data Flow:**
```
ADoApp.swift (entry)
  ↓
AppContainer.getContainer() [Progressive SwiftData container creation]
  ↓
SyncProgressManager.startInitialSync()
  ├─ AppleRemindersSyncManager (bidirectional)
  ├─ CloudKitManager (iCloud sync)
  └─ CalendarManager (EventKit)
  ↓
ContentView → AppRouter (deep link navigation)
```

### Key Architectural Components

#### 1. Data Layer (`Models/`)
- **SwiftData models** with CloudKit integration
- 40+ `@Model` classes including:
  - Core: `Reminder`, `ReminderList`, `Tag`, `LocationTrigger`
  - Features: `Habit`, `TimeEntry`, `RecurringReminder`, `SharedList`
  - AI/ML: `AISuggestion`, `AILearningData`, `AIInsight`
- Progressive container creation in `AppContainer.swift` with fault-tolerant fallback
- Models include validation in initializers (coordinate clamping, string trimming)

#### 2. Manager Layer (`Managers/`)
All managers are `@MainActor` singletons accessed via `.shared`:

**Core Managers:**
- `RemindersManager` - Reminder CRUD operations
- `AppleRemindersSyncManager` - Bidirectional sync with Apple Reminders (throttled to 1-hour intervals)
- `CloudKitManager` - iCloud synchronization with account status monitoring
- `CalendarManager` - EventKit calendar integration
- `LocationManager` - CoreLocation geofencing for location-based reminders
- `NotificationManager` - Local notification scheduling

**AI/ML System (Advanced Feature):**
- `AIManager` - Central AI orchestrator for suggestions and insights
- `BehavioralLearningManager` - Tracks user actions (50-action buffer before processing)
- `MLPatternRecognitionManager` - Analyzes completion patterns, time usage, productivity
- `AIBehavioralIntegrationCoordinator` - Runs hourly learning cycles, coordinates AI subsystems
- `SmartNotificationManager` - Predicts optimal notification timing

**Other Specialized Managers:**
- `GamificationManager`, `HealthKitManager`, `FocusModeManager`, `TimeTrackingManager`
- `CollaborationManager`, `BackupManager`, `AdvancedSearchManager`
- 30+ domain-specific managers

#### 3. View Layer (`Views/`)
SwiftUI views organized by feature area:
- `Home/` - Main dashboard with adaptive iPhone/iPad layouts
- `ReminderForm/` - Complex form handling with validation
- `Habits/` - Habit tracking interface
- `AI/` - AI insights and suggestions dashboard
- `TimeTracking/`, `Templates/`, `Collaboration/`, `Search/`
- `Components/` - Reusable UI components (`GlassCard`, `FlowLayout`, etc.)

#### 4. Styling System
- `AppTheme.swift` - Centralized design system (colors, typography, spacing)
- Uses `.rounded` design language throughout
- `Color+Hex.swift` - Hex color validation and conversion

### AI/ML Behavioral Learning System

**Integration Flow:**
```
User Action (e.g., complete reminder)
  ↓
BehavioralLearningManager.trackAction()
  ↓
AILearningData stored in SwiftData
  ↓
[Hourly cycle]
  ↓
AIBehavioralIntegrationCoordinator.runLearningCycle()
  ├─ MLPatternRecognitionManager.analyzeUserBehaviorPatterns()
  ├─ AIManager.generateSuggestions()
  └─ Store AISuggestion models
```

**Suggestion Types:**
- Due date optimization, priority prediction, habit formation
- Focus optimization, contact recommendations, time estimation
- Task breakdown, delegation, consolidation suggestions

**Key Files:**
- `Managers/AIManager.swift` - Core AI logic
- `Managers/BehavioralLearningManager.swift` - Action tracking
- `Managers/MLPatternRecognitionManager.swift` - Pattern analysis
- `Managers/AIBehavioralIntegrationCoordinator.swift` - System orchestration
- `Models/AIModels.swift` - AI data models

### Sync Architecture

**Multi-Stage Sync Process:**
1. Data Loading
2. Apple Reminders bidirectional sync (throttled: 1 sync/hour max)
3. CloudKit sync (requires iCloud account)
4. Calendar integration
5. Cleanup

**Managed by:** `SyncProgressManager` tracks progress across all stages with UI updates

**Important:** Apple Reminders sync is throttled. Check `AppleRemindersSyncManager` for last sync time before initiating.

### Widget Integration

- **Target:** `a-do_Widget/` (WidgetKit extension)
- **Shared Data:** App Group `group.JAMSoft.a-do`
- **Utilities:** `AppGroupDefaults` and `UserDefaults+AppGroup.swift`
- Widgets share SwiftData container with main app
- Deep links trigger app navigation via `AppRouter`

## Development Guidelines

### SwiftData Best Practices

**Container Access:**
```swift
// Use the shared container for consistent access
let container = AppContainer.shared.getContainer()
```

**Progressive Fallback System:**
- `AppContainer.swift` implements fault-tolerant initialization
- If container creation fails, progressive fallback validates and rebuilds schema
- Debug utilities available: `AppContainer.testContainerCreation()`

**Model Validation:**
- All models include validation in initializers
- Location coordinates clamped to valid Earth ranges (-90 to 90 lat, -180 to 180 lon)
- String inputs trimmed automatically
- Use `SecurityUtils.validateHexColor()` for user-provided colors

### Manager Dependencies

**Threading:**
- Managers are `@MainActor` - UI operations safe
- When calling from background: `Task { @MainActor in }`
- Sync operations run on background threads internally

**Access Pattern:**
```swift
await RemindersManager.shared.createReminder(...)
await AIManager.shared.generateSuggestions()
```

### Deep Links and URL Schemes

**AppRouter handles:**
```
a-do://smart/today              - Today's reminders
a-do://habits                   - Habits view
a-do://tag/{tagName}            - Filter by tag
a-do://priority/{level}         - Filter by priority (high/medium/low)
a-do://ai/suggestions           - AI suggestions
a-do://ai/insights              - AI insights
a-do://sendtext/{reminderId}    - Text contact for reminder
mobilenotes://                  - Apple Notes integration callbacks
```

**Widget Deep Links (via App Group):**
- `deeplink_open_today` - Open today view from widget
- `deeplink_send_text_reminder_id` - Send text from widget

### Entitlements and Capabilities

**Required:**
- CloudKit (Production environment)
- Push Notifications (Time-sensitive alerts)
- App Groups (`group.JAMSoft.a-do`)
- Location Services (background + always authorization)
- EventKit (Calendar and Reminders access)
- Contacts access
- Microphone (voice recording for VoiceReminder)
- HealthKit (optional, for health integration features)

### Performance Considerations

**Implemented Optimizations:**
- Cached filtered reminders in `HomeView` to prevent expensive recomputation
- AI behavioral learning buffers 50 actions before batch processing
- Analytics cache with 1-hour timeout in `AIManager`
- Apple Reminders sync throttled to 1-hour intervals
- Lazy loading in list views (LazyVStack)
- Background async operations for sync

**When Adding Features:**
- Consider impact on sync cycle
- Use buffering for high-frequency events
- Cache expensive computations
- Respect sync throttling intervals

## Debugging Common Issues

### SwiftData Container Issues
- Check logs from `AppContainer` for diagnostic information
- Use `AppContainer.testContainerCreation()` in debug builds for validation
- Progressive fallback system handles most model conflicts automatically
- `SwiftDataUtils.validateModelTypes()` checks model compatibility

### Sync Problems
- Monitor `SyncProgressManager.syncProgress` for stage-specific failures
- CloudKit requires active iCloud account - check `CloudKitManager.accountStatus`
- Apple Reminders sync requires EventKit permission
- Throttling: Apple Reminders syncs max once per hour

### Widget Data Issues
- Verify App Group entitlement matches: `group.JAMSoft.a-do`
- Check `AppGroupDefaults` for data sharing
- Widgets share SwiftData container - model changes require widget rebuild
- Use Xcode Widget simulator for testing

### AI/ML System Issues
- AI suggestions require sufficient behavioral data (tracked in `AILearningData`)
- Learning cycle runs every 1 hour - manual trigger via `AIBehavioralIntegrationCoordinator.runLearningCycle()`
- Check `AIConfiguration.isEnabled` for user opt-in status
- Pattern recognition requires minimum data points (varies by pattern type)

## File Structure

```
a-do/
├── ADoApp.swift                    # App entry point
├── Models/                          # SwiftData @Model entities (40+ models)
├── Managers/                        # Domain-specific singleton managers (30+)
├── ViewModels/                      # MVVM view models
├── Views/                           # SwiftUI views organized by feature
│   ├── Home/, ReminderForm/, Habits/, AI/, TimeTracking/
│   ├── Templates/, Collaboration/, Search/, Tags/, Settings/
│   └── Components/                  # Reusable UI components
├── Shared/                          # Cross-target utilities
│   ├── AppContainer.swift           # SwiftData container factory
│   ├── AppRouter.swift              # Deep link navigation
│   └── AppGroupDefaults.swift       # Widget data sharing
├── Styles/
│   └── AppTheme.swift               # Design system
└── Utils/                           # Utility functions and extensions

a-do_Widget/
├── EnhancedWidgets.swift            # Widget implementations
├── HabitWidget.swift
└── HabitWidgetBundle.swift
```

## Testing Infrastructure

**Current State:**
- No formal XCTest targets currently configured
- Debug utilities available in `#if DEBUG` blocks
- SwiftData diagnostic tools in `SwiftDataUtils.swift`

**Testing Utilities:**
```swift
// Container diagnostics
AppContainer.testContainerCreation()

// Clear test data
AppContainer.clearAllDemoData(context: modelContext)

// Optimize database
AppContainer.optimizeDatabase(context: modelContext)
```

**Logging:**
- Extensive logging via `os.Logger`
- Categories: "a-do", "BehavioralLearning", "MLPatternRecognition", "Sync", etc.
- Check console logs for detailed diagnostics

## Important Implementation Notes

1. **Apple Reminders Sync Throttling:** The `AppleRemindersSyncManager` enforces a 1-hour minimum interval between syncs to avoid overwhelming EventKit. Check `lastSyncTime` before initiating sync.

2. **AI Behavioral Learning Privacy:** User actions are tracked locally in `AILearningData` models. All processing happens on-device. Respect `AIConfiguration.privacyLevel` settings.

3. **Location Triggers:** `LocationTrigger` models must have valid coordinates. The model initializer clamps values automatically, but verify ranges before creation.

4. **Widget Limitations:** Widgets have memory constraints and timeline refresh limits. Keep widget queries efficient and avoid loading excessive data.

5. **CloudKit Sync:** Requires active iCloud account. Always check `CloudKitManager.accountStatus` before attempting sync operations.

6. **Manager Initialization Order:** Some managers depend on others. `ADoApp.swift` handles initialization sequence. Avoid calling manager methods before app fully initializes.
