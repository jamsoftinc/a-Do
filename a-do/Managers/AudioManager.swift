import Foundation
import AVFoundation
import Speech
import os
import Observation

@Observable
final class AudioManager: NSObject, AVAudioRecorderDelegate, SFSpeechRecognizerDelegate {
    static let shared = AudioManager()
    
    // Audio recording
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    // Speech recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // State
    var isRecording = false
    var isTranscribing = false
    var recordingDuration: TimeInterval {
        if let recordingStartedAt {
            return lastRecordedDuration + Date().timeIntervalSince(recordingStartedAt)
        }
        return lastRecordedDuration
    }
    var transcribedText = ""
    var recordingError: String?
    var transcriptionError: String?
    private var recordingStartedAt: Date?
    private var lastRecordedDuration: TimeInterval = 0
    
    // Audio file URL
    private var audioFileURL: URL?
    private var isLiveTranscriptionTapInstalled = false

    // Audio player - must be retained during playback
    private var audioPlayer: AVAudioPlayer?
    private var captureCompletion: CheckedContinuation<Bool, Never>?
    
    private override init() {
        super.init()
        speechRecognizer?.delegate = self
    }
    
    deinit {
        // Clean up resources synchronously to avoid deinit issues
        // Note: We can't call async methods in deinit, so we'll just clean up what we can
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        try? audioSession.setActive(false)
    }
    
    // MARK: - Permission Requests
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission(completionHandler: { granted in
                continuation.resume(returning: granted)
            })
        }
    }
    
    func requestSpeechRecognitionPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    // MARK: - Audio Recording
    
    func startRecording() async {
        // Request permissions
        let microphoneGranted = await requestMicrophonePermission()
        let speechGranted = await requestSpeechRecognitionPermission()
        
        guard microphoneGranted else {
            recordingError = "Microphone access denied. Please enable microphone access in Settings."
            resumeCaptureCompletion(success: false)
            return
        }
        
        guard speechGranted else {
            recordingError = "Speech recognition access denied. Please enable speech recognition in Settings."
            resumeCaptureCompletion(success: false)
            return
        }
        
        // Reset state
        recordingError = nil
        transcribedText = ""
        lastRecordedDuration = 0
        recordingStartedAt = nil
        
        do {
            // Configure audio session
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            // Create audio file URL
            audioFileURL = SecureVoiceFileStore.makeNewFileURL()
            
            guard let audioFileURL = audioFileURL else {
                recordingError = "Failed to create audio file"
                resumeCaptureCompletion(success: false)
                return
            }
            
            // Configure recorder
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            _ = SecureVoiceFileStore.applyProtectedAttributesIfPossible(to: audioFileURL)
            
            isRecording = true
            recordingStartedAt = Date()
            
            Logger(subsystem: "a-do", category: "Audio").info("Started voice recording")
            
        } catch {
            recordingError = "Failed to start recording: \(error.localizedDescription)"
            Logger(subsystem: "a-do", category: "Audio").error("Recording start failed: \(String(describing: error))")
            resumeCaptureCompletion(success: false)
        }
    }
    
    func stopRecording() {
        lastRecordedDuration = recordingDuration
        recordingStartedAt = nil
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        
        // Start transcription
        if let audioFileURL = audioFileURL {
            Task {
                await transcribeAudioFile(url: audioFileURL)
            }
        } else {
            resumeCaptureCompletion(success: false)
        }
        
        Logger(subsystem: "a-do", category: "Audio").info("Stopped voice recording, duration: \(self.recordingDuration)s")
    }
    
    func cancelRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        recordingStartedAt = nil
        lastRecordedDuration = 0
        
        // Delete audio file
        if let audioFileURL = audioFileURL {
            try? FileManager.default.removeItem(at: audioFileURL)
            self.audioFileURL = nil
        }
        
        recordingError = nil
        transcribedText = ""
        transcriptionError = nil
        resumeCaptureCompletion(success: false)
        
        Logger(subsystem: "a-do", category: "Audio").info("Cancelled voice recording")
    }

    func awaitCaptureCompletion(timeoutNanoseconds: UInt64 = 5 * 60 * 1_000_000_000) async -> Bool {
        if !isRecording && !isTranscribing {
            return recordingError == nil && transcriptionError == nil
        }

        return await withTaskGroup(of: Bool.self) { group in
            group.addTask { @MainActor in
                await withCheckedContinuation { continuation in
                    self.captureCompletion?.resume(returning: false)
                    self.captureCompletion = continuation
                }
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return false
            }

            let completed = await group.next() ?? false
            group.cancelAll()

            if !completed {
                await MainActor.run {
                    if self.isRecording {
                        self.stopRecording()
                    }
                    self.resumeCaptureCompletion(success: false)
                }
            }

            return completed
        }
    }
    
    // MARK: - Speech Recognition
    
    private func transcribeAudioFile(url: URL) async {
        self.isTranscribing = true
        self.transcriptionError = nil
        
        do {
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            
                guard let recognizer = recognizer, recognizer.isAvailable else {
                    self.transcriptionError = "Speech recognition is not available"
                    self.isTranscribing = false
                    self.resumeCaptureCompletion(success: false)
                    return
                }
            
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
                recognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let result = result, result.isFinal {
                        continuation.resume(returning: result)
                    }
                }
            }
            
            self.transcribedText = result.bestTranscription.formattedString
            self.isTranscribing = false
            self.resumeCaptureCompletion(success: true)
            
            Logger(subsystem: "a-do", category: "Audio").info("Transcription completed: \(self.transcribedText)")
            
        } catch {
            self.transcriptionError = "Failed to transcribe audio: \(error.localizedDescription)"
            self.isTranscribing = false
            self.resumeCaptureCompletion(success: false)
            Logger(subsystem: "a-do", category: "Audio").error("Transcription failed: \(String(describing: error))")
        }
    }
    
    // MARK: - Audio Playback
    
    func playRecording() async {
        guard let audioFileURL = audioFileURL else { return }

        do {
            // Stop any existing playback
            audioPlayer?.stop()

            // Create and retain player for duration of playback
            audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            Logger(subsystem: "a-do", category: "Audio").error("Playback failed: \(String(describing: error))")
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    // MARK: - File Management

    func getAudioFileURL() -> URL? {
        return audioFileURL
    }

    func setAudioFileURL(_ url: URL) {
        audioFileURL = url
    }

    func deleteAudioFile() {
        if let audioFileURL = audioFileURL {
            try? FileManager.default.removeItem(at: audioFileURL)
            self.audioFileURL = nil
        }
    }

    // MARK: - Real-Time Transcription

    private var audioEngine: AVAudioEngine?
    var liveTranscription = ""

    /// Start real-time transcription as user speaks
    func startLiveTranscription() async {
        let microphoneGranted = await requestMicrophonePermission()
        let speechGranted = await requestSpeechRecognitionPermission()

        guard microphoneGranted && speechGranted else {
            recordingError = "Microphone and speech recognition permissions required"
            return
        }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            transcriptionError = "Speech recognition not available"
            return
        }

        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        if audioEngine != nil || isLiveTranscriptionTapInstalled {
            stopLiveTranscription()
        }

        // Configure audio session
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            transcriptionError = "Failed to configure audio session: \(error.localizedDescription)"
            return
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            transcriptionError = "Unable to create speech recognition request"
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation

        // Initialize audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            transcriptionError = "Unable to create audio engine"
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        isLiveTranscriptionTapInstalled = true

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isRecording = true
            liveTranscription = ""

            // Start recognition task
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let strongSelf = self else { return }

                    if let result = result {
                        strongSelf.liveTranscription = result.bestTranscription.formattedString

                        if result.isFinal {
                            strongSelf.transcribedText = strongSelf.liveTranscription
                            strongSelf.stopLiveTranscription()
                        }
                    }

                    if let error = error {
                        strongSelf.transcriptionError = error.localizedDescription
                        strongSelf.stopLiveTranscription()
                    }
                }
            }

            Logger(subsystem: "a-do", category: "Audio").info("Started live transcription")

        } catch {
            transcriptionError = "Failed to start audio engine: \(error.localizedDescription)"
            isRecording = false
        }
    }

    /// Stop real-time transcription
    func stopLiveTranscription() {
        audioEngine?.stop()
        if isLiveTranscriptionTapInstalled {
            audioEngine?.inputNode.removeTap(onBus: 0)
            isLiveTranscriptionTapInstalled = false
        }
        audioEngine?.reset()
        audioEngine = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isRecording = false
        transcribedText = liveTranscription

        try? audioSession.setActive(false)

        Logger(subsystem: "a-do", category: "Audio").info("Stopped live transcription: \(self.transcribedText)")
    }

    // MARK: - Voice Reminder Creation

    /// Create a VoiceReminder from recorded audio
    func createVoiceReminder(for reminder: Reminder) -> VoiceReminder? {
        guard let audioFileURL = audioFileURL else { return nil }

        let voiceReminder = VoiceReminder(
            audioFileName: audioFileURL.lastPathComponent,
            transcribedText: transcribedText,
            recordingDuration: recordingDuration
        )

        // Associate with reminder
        voiceReminder.reminder = reminder
        reminder.voiceReminder = voiceReminder

        Logger(subsystem: "a-do", category: "Audio").info("Created voice reminder: \(voiceReminder.audioFileName)")

        return voiceReminder
    }

    /// Parse natural language from transcription to extract reminder details
    func parseReminderFromTranscription(_ text: String) -> ParsedReminderDetails {
        var details = ParsedReminderDetails()
        let lowercased = text.lowercased()

        // Extract title (default to full text if no clear task found)
        details.title = extractTitle(from: text)

        // Extract date/time references
        details.dueDate = extractDateTime(from: lowercased)

        // Extract priority
        details.priority = extractPriority(from: lowercased)

        // Extract list/category hints
        details.listHint = extractListHint(from: lowercased)

        return details
    }

    private func extractTitle(from text: String) -> String {
        // Remove common prefixes
        var title = text
        let prefixes = ["remind me to ", "reminder to ", "remember to ", "don't forget to ", "i need to "]

        for prefix in prefixes {
            if title.lowercased().hasPrefix(prefix) {
                title = String(title.dropFirst(prefix.count))
                break
            }
        }

        // Remove time-related suffixes
        let timePatterns = [
            " tomorrow", " today", " tonight", " this morning", " this afternoon", " this evening",
            " at \\d{1,2}(:\\d{2})?( ?[ap]m)?", " on monday", " on tuesday", " on wednesday",
            " on thursday", " on friday", " on saturday", " on sunday", " next week"
        ]

        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                title = regex.stringByReplacingMatches(
                    in: title,
                    range: NSRange(title.startIndex..., in: title),
                    withTemplate: ""
                )
            }
        }

        return title.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
    }

    private func extractDateTime(from text: String) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        // Check for relative time expressions
        if text.contains("tomorrow") {
            var date = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            date = extractTimeAndApply(from: text, to: date)
            return date
        }

        if text.contains("today") || text.contains("tonight") {
            var date = now
            date = extractTimeAndApply(from: text, to: date)
            return date
        }

        if text.contains("next week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        }

        // Check for day names
        let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for (index, dayName) in dayNames.enumerated() {
            if text.contains(dayName) {
                let currentWeekday = calendar.component(.weekday, from: now)
                var daysUntil = index + 1 - currentWeekday
                if daysUntil <= 0 { daysUntil += 7 }

                if let date = calendar.date(byAdding: .day, value: daysUntil, to: now) {
                    return extractTimeAndApply(from: text, to: date)
                }
            }
        }

        // Check for specific time
        if let timeMatch = extractTime(from: text) {
            return calendar.date(bySettingHour: timeMatch.hour, minute: timeMatch.minute, second: 0, of: now)
        }

        return nil
    }

    private func extractTimeAndApply(from text: String, to date: Date) -> Date {
        let calendar = Calendar.current

        if let timeMatch = extractTime(from: text) {
            return calendar.date(bySettingHour: timeMatch.hour, minute: timeMatch.minute, second: 0, of: date) ?? date
        }

        // Default times based on context
        if text.contains("morning") {
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        }
        if text.contains("afternoon") {
            return calendar.date(bySettingHour: 14, minute: 0, second: 0, of: date) ?? date
        }
        if text.contains("evening") || text.contains("tonight") {
            return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date) ?? date
        }

        return date
    }

    private func extractTime(from text: String) -> (hour: Int, minute: Int)? {
        // Match patterns like "3pm", "3:30pm", "15:00"
        let patterns = [
            "\\b(\\d{1,2}):(\\d{2})\\s*([ap]m)?\\b",
            "\\b(\\d{1,2})\\s*([ap]m)\\b"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { continue }

            if match.numberOfRanges >= 2, let hourRange = Range(match.range(at: 1), in: text) {
                var hour = Int(text[hourRange]) ?? 0
                var minute = 0

                if match.numberOfRanges >= 3, let minuteRange = Range(match.range(at: 2), in: text) {
                    let minuteStr = String(text[minuteRange])
                    if minuteStr.lowercased() == "pm" || minuteStr.lowercased() == "am" {
                        // This is actually the AM/PM indicator
                        if minuteStr.lowercased() == "pm" && hour < 12 { hour += 12 }
                        if minuteStr.lowercased() == "am" && hour == 12 { hour = 0 }
                    } else {
                        minute = Int(minuteStr) ?? 0
                    }
                }

                // Check for AM/PM in remaining ranges
                if match.numberOfRanges >= 4, let ampmRange = Range(match.range(at: 3), in: text) {
                    let ampm = String(text[ampmRange]).lowercased()
                    if ampm == "pm" && hour < 12 { hour += 12 }
                    if ampm == "am" && hour == 12 { hour = 0 }
                }

                return (hour, minute)
            }
        }

        return nil
    }

    private func extractPriority(from text: String) -> Priority {
        if text.contains("urgent") || text.contains("important") || text.contains("critical") || text.contains("asap") {
            return .high
        }
        if text.contains("when you can") || text.contains("low priority") || text.contains("whenever") {
            return .low
        }
        return .none
    }

    private func extractListHint(from text: String) -> String? {
        let listKeywords = [
            "work": ["work", "office", "meeting", "project", "client"],
            "personal": ["personal", "home", "family"],
            "shopping": ["buy", "shop", "grocery", "store", "pick up"],
            "health": ["doctor", "appointment", "medicine", "gym", "workout"]
        ]

        for (list, keywords) in listKeywords {
            for keyword in keywords {
                if text.contains(keyword) {
                    return list.capitalized
                }
            }
        }

        return nil
    }

    // MARK: - AVAudioRecorderDelegate

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                recordingError = "Recording failed"
                resumeCaptureCompletion(success: false)
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                recordingError = "Recording error: \(error.localizedDescription)"
                resumeCaptureCompletion(success: false)
            }
        }
    }

    // MARK: - SFSpeechRecognizerDelegate

    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                transcriptionError = "Speech recognition became unavailable"
                resumeCaptureCompletion(success: false)
            }
        }
    }

    private func resumeCaptureCompletion(success: Bool) {
        guard let continuation = captureCompletion else { return }
        captureCompletion = nil
        continuation.resume(returning: success)
    }
}

// MARK: - Parsed Reminder Details

struct ParsedReminderDetails {
    var title: String = ""
    var dueDate: Date?
    var priority: Priority = .none
    var listHint: String?
}
