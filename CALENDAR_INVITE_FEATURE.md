# Calendar Invite Feature

## Overview
The Remember app now supports creating calendar invites directly from reminders, making it easy to schedule meetings and events with attendees.

## Features

### 🗓️ Calendar Invite Creation
- **Form Integration**: Create calendar invites when creating or editing reminders
- **Context Menu**: Quick calendar invite creation from reminder list via context menu
- **Automatic Attendees**: Tagged contacts are automatically added as attendees in event notes
- **Location Support**: Include location information from reminder location triggers
- **Duration Options**: Choose from 15 min, 30 min, 1 hour, 2 hours, or all day
- **Notes Integration**: Reminder details, tags, and attendee list are included in calendar event notes

### 📱 User Interface
- **Calendar Section**: New section in reminder form for calendar invite settings
- **Visual Indicators**: Shows when calendar invites have been created
- **Status Feedback**: Success/error messages for calendar invite creation
- **Smart Defaults**: Pre-fills location from reminder location triggers

### 🔗 Integration Features
- **Contact Integration**: Automatically adds tagged contacts as attendees
- **Location Integration**: Uses reminder location triggers as calendar event location
- **Tag Integration**: Includes reminder tags in calendar event notes
- **Apple Calendar**: Creates events in the user's default calendar

## Usage

### Creating Calendar Invites from Reminder Form
1. Open the reminder form (new or edit)
2. Scroll to the "Calendar Invite" section
3. Toggle "Create Calendar Event" to enable
4. Configure:
   - **Duration**: Select event duration (15 min to all day)
   - **Location**: Optional location for the event
   - **Attendees**: Comma-separated email addresses
5. Save the reminder - calendar invite will be created automatically

### Quick Calendar Invite from Context Menu
1. Long-press on any reminder in the list
2. Select "Create Calendar Invite" from the context menu
3. Calendar invite is created with default settings (30 min duration)

### Automatic Features
- **Tagged Contacts**: Contacts tagged in the reminder are automatically added as attendees
- **Location**: If the reminder has a location trigger, it's used as the calendar event location
- **Notes**: Reminder details and tags are included in the calendar event description

## Technical Implementation

### CalendarManager Enhancements
- `createCalendarInvite()`: Enhanced method with attendee and location support
- Automatic contact email lookup for tagged contacts
- Integration with reminder data for comprehensive event creation

### Reminder Model Updates
- `calendarInviteCreated`: Boolean flag to track if calendar invite exists
- Visual indicators in reminder lists

### ContactsManager Enhancements
- `getEmailForContact()`: Method to retrieve email addresses for contacts
- Supports both contact identifiers and phone numbers

### UI Components
- Calendar invite section in ReminderFormView
- Visual indicators in ReminderRow
- Context menu integration in HomeView

## Security & Privacy
- Calendar access is requested only when needed
- Contact email addresses are retrieved securely
- All calendar operations respect user privacy settings

## Future Enhancements
- Calendar event editing capabilities
- Recurring event support
- Calendar event templates
- Integration with external calendar services
- Calendar event reminders and notifications
