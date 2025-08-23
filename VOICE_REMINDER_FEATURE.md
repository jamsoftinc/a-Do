# Voice Reminder Feature

## Overview
The Remember app now supports creating voice reminders with automatic speech-to-text transcription, making it easy to capture reminders by speaking instead of typing.

## Features

### 🎤 Voice Recording
- **High-quality audio recording**: Records voice reminders in high-quality AAC format
- **Automatic transcription**: Converts speech to text using Apple's Speech Recognition
- **Recording controls**: Start, stop, and cancel recording with visual feedback
- **Duration tracking**: Shows recording duration in real-time
- **Error handling**: Clear error messages for permission and recording issues
- **Quick voice memos**: Start recording directly from the main page for instant capture

### 📝 Smart Integration
- **Auto-title generation**: Transcribed text automatically becomes the reminder title
- **Text editing**: Edit transcribed text after recording
- **Audio playback**: Play back voice recordings to review
- **File management**: Automatic cleanup of audio files when reminders are deleted
- **Quick creation**: One-tap voice reminder creation from main page

### 🎯 User Experience
- **Visual feedback**: Clear recording status with icons and colors
- **Permission handling**: Automatic request for microphone and speech recognition
- **Context menu**: Quick playback from reminder list
- **Visual indicators**: Shows voice recording status in reminder lists
- **Dual access**: Quick recording from main page or full control from form

## Usage

### Creating Voice Reminders
1. **From Main Page (Quick)**: 
   - Tap the microphone button in the toolbar or quick add section
   - Speak your reminder clearly
   - Tap "Stop" when finished
   - Reminder is automatically created with transcribed text

2. **From Reminder Form (Full Control)**:
   - Open the reminder form (new or edit)
   - Scroll to the "Voice Reminder" section
   - Tap "Start Recording" to begin voice recording
   - Speak your reminder clearly
   - Tap "Stop" when finished
   - Wait for automatic transcription
   - Review and edit the transcribed text if needed
   - Save the reminder

### Playing Voice Recordings
- **From reminder form**: Tap the play button in the voice reminder section
- **From context menu**: Long-press on a reminder with voice recording and select "Play Voice Recording"
- **Visual indicator**: Reminders with voice recordings show a waveform icon

### Managing Voice Recordings
- **Delete recording**: Tap "Delete" in the voice reminder section
- **Replace recording**: Delete existing recording and create a new one
- **Edit transcription**: Modify the transcribed text after recording

## Technical Implementation

### AudioManager
- **AVFoundation integration**: High-quality audio recording
- **Speech framework**: Automatic speech-to-text conversion
- **Permission handling**: Microphone and speech recognition permissions
- **File management**: Audio file storage and cleanup
- **Error handling**: Comprehensive error reporting

### VoiceReminder Model
- **Audio file storage**: Stores audio file names and metadata
- **Transcription storage**: Stores transcribed text
- **Duration tracking**: Records audio duration
- **Relationship**: Links to parent reminder

### UI Components
- **Voice reminder section**: Recording interface in reminder form
- **Visual indicators**: Waveform icons and status messages
- **Context menu**: Quick playback options
- **Error display**: Clear error messages for users

## Privacy & Permissions

### Required Permissions
- **Microphone access**: For recording voice reminders
- **Speech recognition**: For converting speech to text

### Privacy Features
- **Local storage**: Audio files stored locally on device
- **No cloud upload**: Voice recordings stay private
- **Automatic cleanup**: Audio files deleted when reminders are removed
- **Permission requests**: Clear explanations of why permissions are needed

## Info.plist Requirements

Add the following keys to your Info.plist:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app uses your microphone to record voice reminders and convert them to text.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>This app uses speech recognition to convert your voice recordings into text for reminders.</string>
```

## Future Enhancements
- **Multiple language support**: Speech recognition in different languages
- **Voice commands**: Create reminders using voice commands
- **Audio editing**: Trim and edit voice recordings
- **Voice notes**: Longer voice notes with multiple recordings
- **Background recording**: Record voice reminders from background
- **Voice reminders**: Audio playback when reminders are due
