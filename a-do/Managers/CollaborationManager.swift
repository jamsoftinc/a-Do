//
//  CollaborationManager.swift
//  a-do
//
//  Collaboration and sharing manager
//

import Foundation
import SwiftData
import CloudKit
import Observation
import Combine
import os

@MainActor
@Observable
final class CollaborationManager: ObservableObject {
    static let shared = CollaborationManager()
    
    private let logger = Logger(subsystem: "a-do", category: "Collaboration")
    private let container = CKContainer(identifier: CloudKitManager.containerIdentifier)

    // Current user info - Secure user identification
    var currentUserID: String?
    var currentUserName: String?
    var currentUserEmail: String?
    var currentUserRecordID: String? {
        return currentUserID // This should be set from CloudKit user record ID
    }
    
    // Sharing state
    var isSharing: Bool = false
    var shareError: String?
    
    private init() {
        Task {
            await fetchUserInfo()
        }
    }
    
    // MARK: - User Info
    
    func fetchUserInfo() async {
        do {
            let userRecordID = try await container.userRecordID()
            currentUserID = userRecordID.recordName
            
            let userRecord = try await container.publicCloudDatabase.record(for: userRecordID)
            currentUserName = userRecord["firstName"] as? String ?? "Unknown"
            currentUserEmail = userRecord["emailAddress"] as? String ?? ""
            
            logger.info("Fetched user info: \(self.currentUserName ?? "Unknown")")
        } catch {
            logger.error("Failed to fetch user info: \(error.localizedDescription)")
            shareError = "Failed to get user information"
            
            // Set fallback values for production
            currentUserID = "user-\(UUID().uuidString)"
            currentUserName = "User"
            currentUserEmail = ""
        }
    }
    
    // MARK: - Reminder Sharing

    func shareReminder(_ reminder: Reminder, with participants: [String], permission: SharingPermission, context: ModelContext) async -> SharedReminder? {
        guard let userID = currentUserID,
              let userName = currentUserName,
              let userEmail = currentUserEmail else {
            shareError = "User information not available"
            return nil
        }
        
        // Validate user ID format
        guard SecurityUtils.isValidUserID(userID) else {
            shareError = "Invalid user credentials"
            logger.warning("Invalid user ID format in shareReminder")
            return nil
        }
        
        // Validate participant email addresses
        let validParticipants = participants.compactMap { email -> String? in
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            return SecurityUtils.isValidEmail(trimmedEmail) ? trimmedEmail : nil
        }
        
        guard !validParticipants.isEmpty else {
            shareError = "No valid participant email addresses provided"
            return nil
        }
        
        // Rate limiting for sharing operations
        let rateLimitKey = "share_\(userID)"
        guard SecurityUtils.isWithinRateLimit(key: rateLimitKey, maxAttempts: 10, timeWindow: 300) else {
            shareError = "Too many sharing requests. Please try again later."
            logger.warning("Share rate limit exceeded for user: \(userID)")
            return nil
        }
        
        isSharing = true
        defer { isSharing = false }
        
        do {
            // Create shared reminder
            let sharedReminder = SharedReminder(
                reminder: reminder,
                ownerID: userID,
                ownerName: userName,
                ownerEmail: userEmail
            )
            
            // Add validated participants
            for participantEmail in validParticipants {
                _ = sharedReminder.addParticipant(
                    userID: "", // Will be filled when they accept
                    email: participantEmail,
                    name: participantEmail, // Will be updated when they join
                    permission: permission
                )
                
                // Send invitation
                await sendInvitation(to: participantEmail, for: sharedReminder)
            }
            
            context.insert(sharedReminder)
            
            // Create CloudKit share
            if let shareRecord = await createCloudKitShare(for: reminder, sharedReminder: sharedReminder) {
                sharedReminder.cloudKitShareID = shareRecord.recordID.recordName
            }
            
            try context.save()
            
            logger.info("Successfully shared reminder: \(reminder.title)")
            return sharedReminder
            
        } catch {
            logger.error("Failed to share reminder: \(error.localizedDescription)")
            shareError = error.localizedDescription
            return nil
        }
    }
    
    func unshareReminder(_ sharedReminder: SharedReminder, context: ModelContext) async {
        isSharing = true
        defer { isSharing = false }
        
        // Revoke CloudKit share
        if let shareID = sharedReminder.cloudKitShareID {
            await revokeCloudKitShare(shareID: shareID)
        }
        
        // Notify participants
        for participant in sharedReminder.participants ?? [] {
            await notifyParticipant(participant, about: .participantRemoved, sharedReminder: sharedReminder)
        }
        
        // Mark as inactive
        sharedReminder.isActive = false
        
        do {
            try context.save()
            logger.info("Unshared reminder: \(sharedReminder.shareTitle)")
        } catch {
            logger.error("Failed to unshare reminder: \(error.localizedDescription)")
        }
    }
    
    // MARK: - List Sharing

    func shareList(_ list: ReminderList, with participants: [String], context: ModelContext) async -> SharedList? {
        guard let userID = currentUserID,
              let userName = currentUserName else {
            shareError = "User information not available"
            return nil
        }
        
        isSharing = true
        defer { isSharing = false }
        
        do {
            let sharedList = SharedList(
                list: list,
                ownerID: userID,
                ownerName: userName
            )
            
            // Add participants
            for participantEmail in participants {
                // Create a temporary SharedReminder for the initializer
                let tempReminder = SharedReminder(
                    reminder: Reminder(),
                    ownerID: userID,
                    ownerName: userName,
                    ownerEmail: currentUserEmail ?? ""
                )
                
                let participant = ShareParticipant(
                    userID: "",
                    email: participantEmail,
                    name: participantEmail,
                    permission: SharingPermission.edit,
                    sharedReminder: tempReminder
                )
                
                // Clear the reminder relationship since this is for list sharing
                participant.sharedReminder = nil
                
                sharedList.participants?.append(participant)
                context.insert(participant)
            }
            
            context.insert(sharedList)
            try context.save()
            
            logger.info("Successfully shared list: \(list.name)")
            return sharedList
            
        } catch {
            logger.error("Failed to share list: \(error.localizedDescription)")
            shareError = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Participant Management
    
    func addParticipant(to sharedReminder: SharedReminder, email: String, permission: SharingPermission, context: ModelContext) async {
        guard sharedReminder.canAcceptNewParticipants else {
            shareError = "Cannot add more participants"
            return
        }
        
        _ = sharedReminder.addParticipant(
            userID: "",
            email: email,
            name: email,
            permission: permission
        )
        
        await sendInvitation(to: email, for: sharedReminder)
        
        do {
            try context.save()
            logger.info("Added participant to shared reminder: \(email)")
        } catch {
            logger.error("Failed to add participant: \(error.localizedDescription)")
        }
    }
    
    func removeParticipant(_ participant: ShareParticipant, from sharedReminder: SharedReminder, context: ModelContext) async {
        sharedReminder.removeParticipant(participant)
        
        await notifyParticipant(participant, about: .participantRemoved, sharedReminder: sharedReminder)
        
        do {
            try context.save()
            logger.info("Removed participant from shared reminder: \(participant.email)")
        } catch {
            logger.error("Failed to remove participant: \(error.localizedDescription)")
        }
    }
    
    func updateParticipantPermission(_ participant: ShareParticipant, newPermission: SharingPermission, in sharedReminder: SharedReminder, context: ModelContext) {
        sharedReminder.updateParticipantPermission(participant, newPermission: newPermission)
        
        Task {
            await notifyParticipant(participant, about: .permissionChanged, sharedReminder: sharedReminder)
        }
        
        do {
            try context.save()
            logger.info("Updated participant permission: \(participant.email) -> \(newPermission.displayName)")
        } catch {
            logger.error("Failed to update participant permission: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Comments
    
    func addComment(to reminder: Reminder, content: String, context: ModelContext) -> ReminderComment? {
        guard let userID = currentUserID,
              let userName = currentUserName else {
            shareError = "User information not available"
            return nil
        }
        
        let comment = ReminderComment(
            content: content,
            authorID: userID,
            authorName: userName,
            reminder: reminder
        )
        
        context.insert(comment)
        
        // Log activity for shared reminders
        if let sharedReminder = getSharedReminder(for: reminder, context: context) {
            sharedReminder.logActivity(
                type: .commentAdded,
                userID: userID,
                userName: userName,
                details: "Added a comment"
            )
            
            // Notify participants
            Task {
                await notifyParticipantsOfComment(sharedReminder: sharedReminder, comment: comment)
            }
        }
        
        do {
            try context.save()
            logger.info("Added comment to reminder: \(reminder.title)")
            return comment
        } catch {
            logger.error("Failed to add comment: \(error.localizedDescription)")
            return nil
        }
    }
    
    func editComment(_ comment: ReminderComment, newContent: String, context: ModelContext) {
        comment.edit(newContent: newContent)
        
        do {
            try context.save()
            logger.info("Edited comment")
        } catch {
            logger.error("Failed to edit comment: \(error.localizedDescription)")
        }
    }
    
    func deleteComment(_ comment: ReminderComment, context: ModelContext) {
        comment.delete()
        
        do {
            try context.save()
            logger.info("Deleted comment")
        } catch {
            logger.error("Failed to delete comment: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Activity Tracking
    
    func logReminderActivity(_ reminder: Reminder, type: ShareActivityType, details: String, context: ModelContext) {
        guard let userID = currentUserID,
              let userName = currentUserName,
              let sharedReminder = getSharedReminder(for: reminder, context: context) else { return }
        
        sharedReminder.logActivity(
            type: type,
            userID: userID,
            userName: userName,
            details: details
        )
        
        do {
            try context.save()
        } catch {
            logger.error("Failed to log activity: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CloudKit Integration
    
    private func createCloudKitShare(for reminder: Reminder, sharedReminder: SharedReminder) async -> CKShare? {
        do {
            // Create a CKRecord for the reminder if it doesn't exist
            let recordID = CKRecord.ID(recordName: reminder.uuid.uuidString)
            let reminderRecord = CKRecord(recordType: "Reminder", recordID: recordID)
            
            // Populate record with reminder data
            reminderRecord["title"] = reminder.title
            reminderRecord["details"] = reminder.details
            reminderRecord["dueDate"] = reminder.dueDate
            reminderRecord["isCompleted"] = reminder.isCompleted
            reminderRecord["priority"] = reminder.priorityRaw
            
            // Create the share
            let share = CKShare(rootRecord: reminderRecord)
            share.publicPermission = .none
            share.participants.forEach { participant in
                participant.permission = .readWrite
                // acceptanceStatus is read-only and managed by CloudKit
            }
            
            // Save to CloudKit
            let database = container.privateCloudDatabase
            let _ = try await database.modifyRecords(saving: [reminderRecord, share], deleting: [])
            
            logger.info("Created CloudKit share for reminder")
            return share
            
        } catch {
            logger.error("Failed to create CloudKit share: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func revokeCloudKitShare(shareID: String) async {
        do {
            let recordID = CKRecord.ID(recordName: shareID)
            let database = container.privateCloudDatabase
            let _ = try await database.deleteRecord(withID: recordID)
            
            logger.info("Revoked CloudKit share")
        } catch {
            logger.error("Failed to revoke CloudKit share: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Notifications
    
    private func sendInvitation(to email: String, for sharedReminder: SharedReminder) async {
        // In a real implementation, this would send an email or push notification
        logger.info("Sending invitation to: \(email)")
        
        // For now, we'll just log it
        // In production, integrate with email service or push notifications
    }
    
    private func notifyParticipant(_ participant: ShareParticipant, about event: ShareActivityType, sharedReminder: SharedReminder) async {
        guard participant.notifyOnChanges else { return }
        
        logger.info("Notifying participant \(participant.email) about \(event.displayName)")
        
        // In production, send push notification or email
    }
    
    private func notifyParticipantsOfComment(sharedReminder: SharedReminder, comment: ReminderComment) async {
        for participant in sharedReminder.activeParticipants {
            if participant.notifyOnComments && participant.userID != comment.authorID {
                await notifyParticipant(participant, about: .commentAdded, sharedReminder: sharedReminder)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getSharedReminder(for reminder: Reminder, context: ModelContext) -> SharedReminder? {
        let reminderUUID = reminder.uuid
        let descriptor = FetchDescriptor<SharedReminder>(
            predicate: #Predicate { $0.reminderID == reminderUUID && $0.isActive }
        )
        
        return try? context.fetch(descriptor).first
    }
    
    func getSharedReminders(context: ModelContext) -> [SharedReminder] {
        let descriptor = FetchDescriptor<SharedReminder>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.lastModified, order: .reverse)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func getParticipatingReminders(context: ModelContext) -> [SharedReminder] {
        guard let userID = currentUserID else { return [] }
        
        let acceptedStatus = ShareStatus.accepted
        let descriptor = FetchDescriptor<SharedReminder>(
            predicate: #Predicate { sharedReminder in
                sharedReminder.isActive && (sharedReminder.participants?.contains { participant in
                    participant.userID == userID && participant.status == acceptedStatus
                } ?? false)
            },
            sortBy: [SortDescriptor(\.lastModified, order: .reverse)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func canUserEdit(_ reminder: Reminder, context: ModelContext) -> Bool {
        guard let userID = currentUserID else { return false }

        // Check if this is a shared reminder
        let hasSharedReminders = !(reminder.sharedReminders?.isEmpty ?? true)

        if hasSharedReminders {
            // This is a shared reminder - verify permissions
            if let sharedReminder = getSharedReminder(for: reminder, context: context) {
                // User is owner
                if sharedReminder.ownerID == userID {
                    return true
                }

                // Check participant permissions
                if let participant = sharedReminder.participants?.first(where: { $0.userID == userID }) {
                    return participant.permission.canEdit && participant.status.isActive
                }
            }
            // Shared reminder exists but user not found in permissions - deny access
            return false
        }

        // Non-shared (personal) reminder - allow edit
        return true
    }
    
    // MARK: - Workspace Management

    func createWorkspace(name: String, description: String, context: ModelContext) -> Workspace? {
        guard let userID = currentUserID,
              let userName = currentUserName else {
            shareError = "User information not available"
            return nil
        }
        
        let workspace = Workspace(name: name, ownerID: userID, ownerName: userName)
        workspace.workspaceDescription = description
        
        // Add owner as first member
        let ownerMember = workspace.addMember(
            userID: userID,
            email: currentUserEmail ?? "",
            name: userName,
            role: .owner
        )
        ownerMember.status = .active
        
        context.insert(workspace)
        
        do {
            try context.save()
            logger.info("Created workspace: \(name)")
            return workspace
        } catch {
            logger.error("Failed to create workspace: \(error.localizedDescription)")
            shareError = error.localizedDescription
            return nil
        }
    }
    
    func inviteToWorkspace(_ workspace: Workspace, email: String, role: WorkspaceRole, context: ModelContext) {
        guard workspace.canAddMembers else {
            shareError = "Workspace is at member limit"
            return
        }
        
        let member = workspace.addMember(
            userID: "",
            email: email,
            name: email,
            role: role
        )
        
        member.invitedBy = currentUserID ?? ""
        
        do {
            try context.save()
            logger.info("Invited \(email) to workspace: \(workspace.name)")
            
            // Send invitation
            Task {
                await sendWorkspaceInvitation(to: email, workspace: workspace)
            }
        } catch {
            logger.error("Failed to invite to workspace: \(error.localizedDescription)")
        }
    }
    
    private func sendWorkspaceInvitation(to email: String, workspace: Workspace) async {
        logger.info("Sending workspace invitation to: \(email)")
        // Implement email/notification sending
    }
    
    // MARK: - Invitation Management
    
    func acceptInvitation(_ participant: ShareParticipant, context: ModelContext) async {
        participant.status = ShareStatus.accepted
        participant.respondedAt = Date()
        
        do {
            try context.save()
            logger.info("Accepted invitation for participant: \(participant.email)")
        } catch {
            logger.error("Failed to accept invitation: \(error.localizedDescription)")
        }
    }
    
    func declineInvitation(_ participant: ShareParticipant, context: ModelContext) async {
        participant.status = ShareStatus.declined
        participant.respondedAt = Date()

        do {
            try context.save()
            logger.info("Declined invitation for participant: \(participant.email)")
        } catch {
            logger.error("Failed to decline invitation: \(error.localizedDescription)")
        }
    }

    // MARK: - Translation Integration

    func translateCommentForUser(_ comment: ReminderComment, targetLanguage: SupportedLanguage) async -> String? {
        // Translation is a Pro feature
        guard EntitlementManager.shared.isProUser else {
            logger.warning("Translation is a Pro feature")
            return nil
        }

        let translationManager = TranslationManager.shared

        guard translationManager.translateComments else {
            return nil
        }

        if #available(iOS 17.4, *) {
            return await translationManager.translate(
                text: comment.content,
                to: targetLanguage
            )
        } else {
            logger.warning("Translation requires iOS 17.4 or later")
            return nil
        }
    }

    func translateReminderForParticipants(
        _ reminder: Reminder,
        participants: [ShareParticipant]
    ) async -> [String: String] {
        // Translation is a Pro feature
        guard EntitlementManager.shared.isProUser else {
            logger.warning("Translation is a Pro feature")
            return [:]
        }

        let translationManager = TranslationManager.shared

        guard translationManager.translateSharedReminders else {
            return [:]
        }

        // Detect source language
        var sourceLanguage: SupportedLanguage = .english
        if #available(iOS 17.4, *) {
            if let detected = await translationManager.detectLanguage(in: reminder.title) {
                sourceLanguage = detected
            }
        }

        // Build user language preferences
        var userLanguages: [String: SupportedLanguage] = [:]
        for participant in participants {
            // In a real implementation, you'd fetch the user's preferred language
            // For now, we'll use English as default
            userLanguages[participant.userID] = translationManager.preferredLanguage
        }

        // Translate title for each participant
        if #available(iOS 17.4, *) {
            return await translationManager.translateSharedContent(
                content: reminder.title,
                fromLanguage: sourceLanguage,
                forUsers: userLanguages
            )
        } else {
            return [:]
        }
    }

    func getTranslatedComment(
        _ comment: ReminderComment,
        for userID: String,
        targetLanguage: SupportedLanguage
    ) async -> String {
        // Try to get translation
        if let translated = await translateCommentForUser(comment, targetLanguage: targetLanguage) {
            return translated
        }

        // Fall back to original content
        return comment.content
    }

    func notifyParticipantsWithTranslation(
        sharedReminder: SharedReminder,
        message: String,
        type: ShareActivityType
    ) async {
        let translationManager = TranslationManager.shared

        guard translationManager.translateSharedReminders else {
            // Send notifications without translation
            for participant in sharedReminder.activeParticipants {
                await notifyParticipant(participant, about: type, sharedReminder: sharedReminder)
            }
            return
        }

        // Detect source language
        var sourceLanguage: SupportedLanguage = .english
        if #available(iOS 17.4, *) {
            if let detected = await translationManager.detectLanguage(in: message) {
                sourceLanguage = detected
            }
        }

        // Send translated notifications to each participant
        for participant in sharedReminder.activeParticipants {
            let targetLanguage = translationManager.preferredLanguage // Should fetch per-user preference

            if #available(iOS 17.4, *), sourceLanguage != targetLanguage {
                if let translatedMessage = await translationManager.translate(
                    text: message,
                    from: sourceLanguage,
                    to: targetLanguage
                ) {
                    logger.info("Sending translated notification to \(participant.email): \(translatedMessage)")
                    await notifyParticipant(participant, about: type, sharedReminder: sharedReminder)
                }
            } else {
                await notifyParticipant(participant, about: type, sharedReminder: sharedReminder)
            }
        }
    }

    func addCommentWithTranslation(
        to reminder: Reminder,
        content: String,
        context: ModelContext,
        shouldTranslate: Bool = true
    ) async -> ReminderComment? {
        guard let comment = addComment(to: reminder, content: content, context: context) else {
            return nil
        }

        // If translation is enabled, notify participants with translated versions
        if shouldTranslate, let sharedReminder = getSharedReminder(for: reminder, context: context) {
            await notifyParticipantsWithTranslation(
                sharedReminder: sharedReminder,
                message: "New comment: \(content)",
                type: .commentAdded
            )
        }

        return comment
    }
}
