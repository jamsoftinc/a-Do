# Location Usage Description

To enable location-based reminders, add the following key to your Info.plist file:

## Required Info.plist Keys

### NSLocationWhenInUseUsageDescription
```
This app uses your location to create location-based reminders that notify you when you arrive at or leave specific places.
```

### NSLocationAlwaysAndWhenInUseUsageDescription
```
This app uses your location to create location-based reminders that notify you when you arrive at or leave specific places, even when the app is in the background.
```

## How to Add in Xcode

1. Open your Xcode project
2. Select your target
3. Go to the "Info" tab
4. Add the keys above with their corresponding descriptions
5. Or add them directly to Info.plist:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app uses your location to create location-based reminders that notify you when you arrive at or leave specific places.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app uses your location to create location-based reminders that notify you when you arrive at or leave specific places, even when the app is in the background.</string>
```

## Background Location Usage

For background location monitoring, also ensure you have:
- Background Modes capability enabled
- Location updates background mode selected
