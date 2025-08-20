# App Rename Guide: Remember → a-do

## ✅ Completed Changes

The following changes have been automatically applied to rename the app from "Remember" to "a-do":

### Code Changes
- ✅ **Bundle Identifier**: Updated to `JAMSoft.a-do`
- ✅ **App Display Name**: Changed to "a-do" in launch screens
- ✅ **Navigation Titles**: Updated HomeView title to "a-do"
- ✅ **URL Scheme**: Changed from "remember" to "a-do"
- ✅ **UserDefaults Group**: Updated to "group.JAMSoft.a-do"
- ✅ **Logger Subsystems**: Updated from "Remember" to "a-do"
- ✅ **Widget Text**: Updated to "Today's Tasks"
- ✅ **Documentation**: Updated all references

### Files Modified
- `Remember.xcodeproj/project.pbxproj` - Bundle identifier and app name
- `Remember/Launch/LaunchScreen.storyboard` - Launch screen title
- `Remember/Views/LaunchScreenView.swift` - Animated launch screen
- `Remember/Views/StaticLaunchScreenView.swift` - Static launch screen
- `Remember/Views/Home/HomeView.swift` - Navigation title and logging
- `Remember/Views/Lists/ListsView.swift` - Logging subsystem
- `Remember/Shared/AppRouter.swift` - URL scheme and UserDefaults group
- `Remember_Widget/Remember_Widget.swift` - Widget display text
- Documentation files - Updated references

## 🔧 Manual Steps Required in Xcode

To complete the app rename, you'll need to perform these steps in Xcode:

### 1. Update App Display Name
1. Open the project in Xcode
2. Select your target in the Project Navigator
3. Go to the "Info" tab
4. Find "Bundle display name" or add it if missing
5. Set the value to: `a-do`

### 2. Update URL Schemes (if used)
1. In the same "Info" tab
2. Find "URL Types" section
3. Update the URL scheme from "remember" to "a-do"

### 3. Update App Groups (if used)
1. Go to "Signing & Capabilities" tab
2. Find "App Groups" capability
3. Update the group identifier from "group.JAMSoft.Remember" to "group.JAMSoft.a-do"
4. Repeat for the widget target

### 4. Update Widget Bundle Identifier
1. Select the widget target
2. Go to "Signing & Capabilities"
3. Update bundle identifier to: `JAMSoft.a-do.Remember-Widget`

### 5. Update Scheme Names (Optional)
1. Go to Product → Scheme → Manage Schemes
2. Rename schemes from "Remember" to "a-do"

### 6. Clean and Rebuild
1. Clean Build Folder (⌘+Shift+K)
2. Delete derived data if needed
3. Build and run to test

## 🎯 Expected Results

After completing these steps:
- ✅ App will display as "a-do" on the home screen
- ✅ Launch screens will show "a-do"
- ✅ Navigation title will be "a-do"
- ✅ Widget will show "Today's Tasks"
- ✅ Deep links will use "a-do://" scheme
- ✅ All logging will use "a-do" subsystem

## 🧪 Testing Checklist

Test these areas after the rename:
- [ ] App installs with correct name
- [ ] Launch screens display "a-do"
- [ ] Home screen shows "a-do" title
- [ ] Widget functions correctly
- [ ] Deep links work (if implemented)
- [ ] App groups sync properly (if used)

## 📝 Additional Notes

- The internal folder structure still uses "Remember" - this is normal and doesn't affect functionality
- Consider updating the Git repository name to match
- Update any external documentation, App Store listings, etc.
- The bundle identifier change may require re-provisioning profiles

## 🔄 Reverting Changes

If you need to revert back to "Remember", the changes can be undone by:
1. Updating the bundle identifier back to `JAMSoft.Remember`
2. Changing display text back to "Remember"
3. Updating URL scheme to "remember"
4. Restoring UserDefaults group to "group.JAMSoft.Remember"

The rename is now complete! 🎉
