//
//  SharePlayManager.swift
//  a-do
//
//  SharePlay Integration for Collaborative Focus Sessions
//

import Foundation
import GroupActivities
import Observation
import os
import Combine

@MainActor
@Observable
final class SharePlayManager {
    static let shared = SharePlayManager()

    private let logger = Logger(subsystem: "a-do", category: "SharePlay")

    // Pro feature check
    var isProEnabled: Bool {
        return EntitlementManager.shared.canUseSharePlay
    }

    var isActive: Bool = false
    var currentSession: SharePlaySession?
    var participants: [Participant] = []
    var groupSession: GroupSession<FocusGroupActivity>?
    var messenger: GroupSessionMessenger?

    private var subscriptions = Set<AnyCancellable>()

    private init() {
        setupSessionMonitoring()
    }

    // MARK: - Session Monitoring

    private func setupSessionMonitoring() {
        Task {
            for await session in FocusGroupActivity.sessions() {
                await configureGroupSession(session)
            }
        }
    }

    private func configureGroupSession(_ session: GroupSession<FocusGroupActivity>) async {
        groupSession = session
        messenger = GroupSessionMessenger(session: session)

        // Join the session
        session.join()

        // Monitor participants
        session.$activeParticipants
            .sink { [weak self] activeParticipants in
                guard let self = self else { return }
                Task { @MainActor in
                    self.participants = activeParticipants.map { participant in
                        Participant(
                            id: participant.id,
                            name: "User \(participant.id.uuidString.prefix(8))",
                            isActive: true
                        )
                    }
                    self.logger.info("Updated participants: \(self.participants.count)")
                }
            }
            .store(in: &subscriptions)

        // Monitor session state
        session.$state
            .sink { [weak self] state in
                guard let self = self else { return }
                Task { @MainActor in
                    switch state {
                    case .waiting:
                        self.logger.info("SharePlay session waiting")
                    case .joined:
                        self.logger.info("SharePlay session joined")
                        self.isActive = true
                    case .invalidated:
                        self.logger.info("SharePlay session invalidated")
                        self.endSharePlaySession()
                    @unknown default:
                        break
                    }
                }
            }
            .store(in: &subscriptions)

        // Listen for messages
        if let messenger = messenger {
            Task {
                for await (message, _) in messenger.messages(of: SessionMessage.self) {
                    await handleMessage(message)
                }
            }
        }

        self.isActive = true
        logger.info("Group session configured with \(session.activeParticipants.count) participants")
    }

    // MARK: - Session Management

    func startSharePlaySession(_ session: FocusSession) async -> Bool {
        guard isProEnabled else {
            logger.warning("SharePlay is a Pro feature")
            return false
        }

        logger.info("Starting SharePlay session: \(session.name)")

        let sharePlaySession = SharePlaySession(focusSession: session)

        // Create Group Activity
        let activity = FocusGroupActivity(session: sharePlaySession)

        do {
            _ = try await activity.activate()
            self.currentSession = sharePlaySession
            logger.info("SharePlay session activated successfully")
            return true
        } catch {
            logger.error("Failed to start SharePlay session: \(error.localizedDescription)")
            return false
        }
    }

    func endSharePlaySession() {
        guard isActive else { return }

        logger.info("Ending SharePlay session")
        groupSession?.leave()
        isActive = false
        currentSession = nil
        participants = []
        subscriptions.removeAll()
    }

    // MARK: - Messaging

    func sendMessage(_ message: SessionMessage) async {
        guard let messenger = messenger else {
            logger.warning("No messenger available")
            return
        }

        do {
            try await messenger.send(message)
            logger.info("Message sent: \(message.type.rawValue)")
        } catch {
            logger.error("Failed to send message: \(error.localizedDescription)")
        }
    }

    private func handleMessage(_ message: SessionMessage) async {
        logger.info("Received message: \(message.type.rawValue)")

        switch message.type {
        case .taskCompleted:
            logger.info("Task completed by participant: \(message.content)")
        case .breakStarted:
            logger.info("Break started by participant")
        case .focusResumed:
            logger.info("Focus resumed by participant")
        case .encouragement:
            logger.info("Encouragement received: \(message.content)")
        }
    }

    func sendTaskCompletion(taskTitle: String) async {
        let message = SessionMessage(type: .taskCompleted, content: taskTitle, senderId: UUID())
        await sendMessage(message)
    }

    func sendBreakNotification() async {
        let message = SessionMessage(type: .breakStarted, content: "Taking a break", senderId: UUID())
        await sendMessage(message)
    }

    func sendEncouragement(_ text: String) async {
        let message = SessionMessage(type: .encouragement, content: text, senderId: UUID())
        await sendMessage(message)
    }
}

// MARK: - Group Activity

struct FocusGroupActivity: GroupActivity {
    let session: SharePlaySession
    
    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "Focus Session: \(session.name)"
        metadata.subtitle = "Working together"
        metadata.type = .generic
        return metadata
    }
}

// MARK: - Supporting Types

struct SharePlaySession: Codable {
    let id: UUID
    let name: String
    let duration: TimeInterval
    let startTime: Date
    let participants: [Participant]

    init(focusSession: FocusSession) {
        self.id = UUID()
        self.name = focusSession.name
        self.duration = focusSession.plannedDuration
        self.startTime = Date()
        self.participants = []
    }
}

struct Participant: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let isActive: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Participant, rhs: Participant) -> Bool {
        lhs.id == rhs.id
    }
}

struct SessionMessage: Codable {
    let id: UUID
    let type: MessageType
    let content: String
    let senderId: UUID
    let timestamp: Date

    init(type: MessageType, content: String, senderId: UUID) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.senderId = senderId
        self.timestamp = Date()
    }

    enum MessageType: String, Codable {
        case taskCompleted
        case breakStarted
        case focusResumed
        case encouragement
    }
}
