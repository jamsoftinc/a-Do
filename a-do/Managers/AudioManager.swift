import Foundation
import AVFoundation
import Speech
import os
import Observation

@MainActor
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
    var recordingDuration: TimeInterval = 0
    var transcribedText = ""
    var recordingError: String?
    var transcriptionError: String?
    
    // Recording timer
    private var recordingTimer: Timer?
    
    // Audio file URL
    private var audioFileURL: URL?
    
    private override init() {
        super.init()
        speechRecognizer?.delegate = self
    }
    
    // MARK: - Permission Requests
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
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
            return
        }
        
        guard speechGranted else {
            recordingError = "Speech recognition access denied. Please enable speech recognition in Settings."
            return
        }
        
        // Reset state
        recordingError = nil
        transcribedText = ""
        recordingDuration = 0
        
        do {
            // Configure audio session
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            // Create audio file URL
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFileName = "voice_reminder_\(Date().timeIntervalSince1970).m4a"
            audioFileURL = documentsPath.appendingPathComponent(audioFileName)
            
            guard let audioFileURL = audioFileURL else {
                recordingError = "Failed to create audio file"
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
            
            isRecording = true
            
            // Start timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                self.recordingDuration += 1.0
            }
            
            Logger(subsystem: "a-do", category: "Audio").info("Started voice recording")
            
        } catch {
            recordingError = "Failed to start recording: \(error.localizedDescription)"
            Logger(subsystem: "a-do", category: "Audio").error("Recording start failed: \(String(describing: error))")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Start transcription
        if let audioFileURL = audioFileURL {
            Task {
                await transcribeAudioFile(url: audioFileURL)
            }
        }
        
        Logger(subsystem: "a-do", category: "Audio").info("Stopped voice recording, duration: \(self.recordingDuration)s")
    }
    
    func cancelRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Delete audio file
        if let audioFileURL = audioFileURL {
            try? FileManager.default.removeItem(at: audioFileURL)
            self.audioFileURL = nil
        }
        
        recordingError = nil
        transcribedText = ""
        recordingDuration = 0
        
        Logger(subsystem: "a-do", category: "Audio").info("Cancelled voice recording")
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
            
            Logger(subsystem: "a-do", category: "Audio").info("Transcription completed: \(self.transcribedText)")
            
        } catch {
            self.transcriptionError = "Failed to transcribe audio: \(error.localizedDescription)"
            self.isTranscribing = false
            Logger(subsystem: "a-do", category: "Audio").error("Transcription failed: \(String(describing: error))")
        }
    }
    
    // MARK: - Audio Playback
    
    func playRecording() async {
        guard let audioFileURL = audioFileURL else { return }
        
        do {
            let player = try AVAudioPlayer(contentsOf: audioFileURL)
            player.play()
        } catch {
            Logger(subsystem: "a-do", category: "Audio").error("Playback failed: \(String(describing: error))")
        }
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
    
    // MARK: - AVAudioRecorderDelegate
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            recordingError = "Recording failed"
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            recordingError = "Recording error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - SFSpeechRecognizerDelegate
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            transcriptionError = "Speech recognition became unavailable"
        }
    }
}
