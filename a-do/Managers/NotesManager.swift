import Foundation
import os
import Observation
import UIKit
import EventKit
import SwiftData

@MainActor
@Observable
final class NotesManager {
    static let shared = NotesManager()
    private let notesStore = NotesStore()
    
    var authorizationStatus: NotesAuthorizationStatus = .notDetermined
    
    private init() {}
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notesStore.requestAuthorization()
            self.authorizationStatus = granted ? .authorized : .denied
            return granted
        } catch {
            Logger(subsystem: "a-do", category: "Notes").error("Notes authorization failed: \(String(describing: error))")
            self.authorizationStatus = .denied
            return false
        }
    }
    
    func fetchNotes(context: ModelContext? = nil) async -> [Note] {
        // Check if Apple Notes integration is enabled
        if let context = context {
            let settings = SettingsManager.shared.getSettings(context: context)
            guard settings.appleNotesEnabled else {
                Logger(subsystem: "a-do", category: "Notes").info("Apple Notes integration is disabled")
                return []
            }
        }
        
        guard authorizationStatus == .authorized else { return [] }
        
        do {
            let notes = try await notesStore.fetchNotes()
            return notes
        } catch {
            Logger(subsystem: "a-do", category: "Notes").error("Failed to fetch notes: \(String(describing: error))")
            return []
        }
    }
    
    func createNote(title: String, content: String, context: ModelContext? = nil) async -> Note? {
        // Check if Apple Notes integration is enabled
        if let context = context {
            let settings = SettingsManager.shared.getSettings(context: context)
            guard settings.appleNotesEnabled else {
                Logger(subsystem: "a-do", category: "Notes").info("Apple Notes integration is disabled")
                return nil
            }
        }
        
        guard authorizationStatus == .authorized else { return nil }
        
        do {
            let note = try await notesStore.createNote(title: title, content: content)
            return note
        } catch {
            Logger(subsystem: "a-do", category: "Notes").error("Failed to create note: \(String(describing: error))")
            return nil
        }
    }
    
    func updateNote(_ note: Note, title: String, content: String) async -> Bool {
        guard authorizationStatus == .authorized else { return false }
        
        do {
            try await notesStore.updateNote(note, title: title, content: content)
            return true
        } catch {
            Logger(subsystem: "a-do", category: "Notes").error("Failed to update note: \(String(describing: error))")
            return false
        }
    }
    
    func deleteNote(_ note: Note) async -> Bool {
        guard authorizationStatus == .authorized else { return false }
        
        do {
            try await notesStore.deleteNote(note)
            return true
        } catch {
            Logger(subsystem: "a-do", category: "Notes").error("Failed to delete note: \(String(describing: error))")
            return false
        }
    }
    
    func createAppleNoteAttachment(from note: Note) -> AppleNoteAttachment {
        return AppleNoteAttachment(
            noteIdentifier: note.identifier,
            noteTitle: note.title,
            noteContent: note.content,
            lastModified: note.modificationDate
        )
    }
    
    func openNoteInNotesApp(noteIdentifier: String) {
        guard let url = URL(string: "mobilenotes://note/\(noteIdentifier)") else { return }
        
        Task {
            await UIApplication.shared.open(url)
        }
    }
}

// MARK: - Notes Framework Types
// These are simplified versions of the actual Notes framework types
// In a real implementation, you would import the actual Notes framework

struct Note: Identifiable, Hashable {
    let id = UUID()
    let identifier: String
    let title: String
    let content: String
    let creationDate: Date
    let modificationDate: Date
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
    
    static func == (lhs: Note, rhs: Note) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

enum NotesAuthorizationStatus {
    case notDetermined
    case denied
    case authorized
}

enum NotesError: Error {
    case creationFailed
    case updateFailed
    case deletionFailed
    case authorizationDenied
}

class NotesStore {
    func requestAuthorization() async throws -> Bool {
        // Use the real Notes manager for authorization
        return await RealNotesManager.shared.requestAuthorization()
    }
    
    func fetchNotes() async throws -> [Note] {
        // Use the real Notes manager to fetch notes
        return await RealNotesManager.shared.fetchNotes()
    }
    
    func createNote(title: String, content: String) async throws -> Note {
        // Use the real Notes manager to create notes
        if let note = await RealNotesManager.shared.createNote(title: title, content: content) {
            return note
        } else {
            throw NotesError.creationFailed
        }
    }
    
    func updateNote(_ note: Note, title: String, content: String) async throws {
        let success = await RealNotesManager.shared.updateNote(note, title: title, content: content)
        if !success {
            throw NotesError.updateFailed
        }
    }
    
    func deleteNote(_ note: Note) async throws {
        let success = await RealNotesManager.shared.deleteNote(note)
        if !success {
            throw NotesError.deletionFailed
        }
    }
}

