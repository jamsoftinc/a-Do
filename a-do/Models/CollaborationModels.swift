//
//  CollaborationModels.swift
//  a-do
//
//  Collaboration and sharing models
//

import Foundation
import SwiftData
import CloudKit

// MARK: - Sharing Permissions
enum SharingPermission: String, CaseIterable, Codable {
    case view = "view"
    case edit = "edit"
    case admin = "admin"
    
    var displayName: String {
        switch self {
        case .view: return "View Only"
        case .edit: return "Can Edit"
        case .admin: return "Admin"
        }
    }
    
    var canEdit: Bool {
        return self == .edit || self == .admin
    }
    
    var canManageSharing: Bool {
        return self == .admin
    }
}

// MARK: - Share Status
enum ShareStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case revoked = "revoked"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .revoked: return "Revoked"
        }
    }
    
    var isActive: Bool {
        return self == .accepted
    }
}

// MARK: - Shared Reminder
@Model
final class SharedReminder {
    var id: UUID = UUID()
    var reminderID: UUID = UUID() // Reference to the original reminder
    var ownerID: String = "" // CloudKit user ID
    var ownerName: String = ""
    var ownerEmail: String = ""
    var sharedAt: Date = Date()
    var lastModified: Date = Date()
    var lastModifiedBy: String = ""
    var isActive: Bool = true
    
    // Sharing metadata
    var shareTitle: String = ""
    var shareMessage: String = ""
    var expirationDate: Date?
    var maxParticipants: Int = 10
    var allowPublicAccess: Bool = false
    var requireApproval: Bool = true
    
    // CloudKit sharing
    var cloudKitShareID: String?
    var cloudKitRecordID: String?
    
    // Relationships
    @Relationship(deleteRule: .cascade) var participants: [ShareParticipant] = []
    @Relationship(deleteRule: .cascade) var activities: [ShareActivity] = []
    @Relationship(deleteRule: .nullify) var reminder: Reminder?
    
    init(reminder: Reminder, ownerID: String, ownerName: String, ownerEmail: String) {
        self.reminderID = reminder.uuid
        self.reminder = reminder
        self.ownerID = ownerID
        self.ownerName = ownerName
        self.ownerEmail = ownerEmail
        self.shareTitle = "Shared: \(reminder.title)"
        self.sharedAt = Date()
        self.lastModified = Date()
        self.lastModifiedBy = ownerID
    }
    
    // MARK: - Computed Properties
    
    var activeParticipants: [ShareParticipant] {
        return participants.filter { $0.status.isActive }
    }
    
    var pendingParticipants: [ShareParticipant] {
        return participants.filter { $0.status == .pending }
    }
    
    var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return expirationDate < Date()
    }
    
    var canAcceptNewParticipants: Bool {
        return isActive && !isExpired && activeParticipants.count < maxParticipants
    }
    
    // MARK: - Participant Management
    
    func addParticipant(userID: String, email: String, name: String, permission: SharingPermission) -> ShareParticipant {
        let participant = ShareParticipant(
            userID: userID,
            email: email,
            name: name,
            permission: permission,
            sharedReminder: self
        )
        
        participants.append(participant)
        
        // Log activity
        logActivity(
            type: .participantAdded,
            userID: ownerID,
            userName: ownerName,
            details: "Added \(name) with \(permission.displayName) permission"
        )
        
        return participant
    }
    
    func removeParticipant(_ participant: ShareParticipant) {
        if let index = participants.firstIndex(of: participant) {
            participants.remove(at: index)
            
            logActivity(
                type: .participantRemoved,
                userID: ownerID,
                userName: ownerName,
                details: "Removed \(participant.name)"
            )
        }
    }
    
    func updateParticipantPermission(_ participant: ShareParticipant, newPermission: SharingPermission) {
        let oldPermission = participant.permission
        participant.permission = newPermission
        participant.lastModified = Date()
        
        logActivity(
            type: .permissionChanged,
            userID: ownerID,
            userName: ownerName,
            details: "Changed \(participant.name)'s permission from \(oldPermission.displayName) to \(newPermission.displayName)"
        )
    }
    
    // MARK: - Activity Logging
    
    func logActivity(type: ShareActivityType, userID: String, userName: String, details: String) {
        let activity = ShareActivity(
            type: type,
            userID: userID,
            userName: userName,
            details: details,
            sharedReminder: self
        )
        
        activities.append(activity)
        lastModified = Date()
        lastModifiedBy = userID
    }
}

// MARK: - Share Participant
@Model
final class ShareParticipant {
    var id: UUID = UUID()
    var userID: String = ""
    var email: String = ""
    var name: String = ""
    var permission: SharingPermission = SharingPermission.view
    var status: ShareStatus = ShareStatus.pending
    var invitedAt: Date = Date()
    var respondedAt: Date?
    var lastActive: Date?
    var lastModified: Date = Date()
    
    // Notification preferences
    var notifyOnChanges: Bool = true
    var notifyOnComments: Bool = true
    var notifyOnCompletion: Bool = true
    
    // CloudKit user info
    var cloudKitUserID: String?
    var avatarURL: String?
    
    @Relationship(deleteRule: .nullify) var sharedReminder: SharedReminder?
    
    init(userID: String, email: String, name: String, permission: SharingPermission, sharedReminder: SharedReminder) {
        self.userID = userID
        self.email = email
        self.name = name
        self.permission = permission
        self.sharedReminder = sharedReminder
        self.invitedAt = Date()
        self.lastModified = Date()
    }
    
    // MARK: - Status Management
    
    func accept() {
        status = .accepted
        respondedAt = Date()
        lastActive = Date()
        lastModified = Date()
    }
    
    func decline() {
        status = .declined
        respondedAt = Date()
        lastModified = Date()
    }
    
    func revoke() {
        status = .revoked
        lastModified = Date()
    }
    
    // MARK: - Activity Tracking
    
    func updateLastActive() {
        lastActive = Date()
    }
    
    var isRecentlyActive: Bool {
        guard let lastActive = lastActive else { return false }
        return Date().timeIntervalSince(lastActive) < 3600 // Within last hour
    }
}

// MARK: - Share Activity
@Model
final class ShareActivity {
    var id: UUID = UUID()
    var type: ShareActivityType = ShareActivityType.reminderCreated
    var userID: String = ""
    var userName: String = ""
    var details: String = ""
    var timestamp: Date = Date()
    var metadata: Data? // JSON data for additional context
    
    @Relationship(deleteRule: .nullify) var sharedReminder: SharedReminder?
    
    init(type: ShareActivityType, userID: String, userName: String, details: String, sharedReminder: SharedReminder) {
        self.type = type
        self.userID = userID
        self.userName = userName
        self.details = details
        self.sharedReminder = sharedReminder
        self.timestamp = Date()
    }
    
    // MARK: - Metadata Helpers
    
    func setMetadata<T: Codable>(_ data: T) {
        metadata = try? JSONEncoder().encode(data)
    }
    
    func getMetadata<T: Codable>(as type: T.Type) -> T? {
        guard let metadata = metadata else { return nil }
        return try? JSONDecoder().decode(type, from: metadata)
    }
}

// MARK: - Share Activity Type
enum ShareActivityType: String, CaseIterable, Codable {
    case reminderCreated = "reminder_created"
    case reminderUpdated = "reminder_updated"
    case reminderCompleted = "reminder_completed"
    case reminderDeleted = "reminder_deleted"
    case participantAdded = "participant_added"
    case participantRemoved = "participant_removed"
    case permissionChanged = "permission_changed"
    case commentAdded = "comment_added"
    case attachmentAdded = "attachment_added"
    case dueDateChanged = "due_date_changed"
    case priorityChanged = "priority_changed"
    case tagAdded = "tag_added"
    case tagRemoved = "tag_removed"
    
    var displayName: String {
        switch self {
        case .reminderCreated: return "Reminder Created"
        case .reminderUpdated: return "Reminder Updated"
        case .reminderCompleted: return "Reminder Completed"
        case .reminderDeleted: return "Reminder Deleted"
        case .participantAdded: return "Participant Added"
        case .participantRemoved: return "Participant Removed"
        case .permissionChanged: return "Permission Changed"
        case .commentAdded: return "Comment Added"
        case .attachmentAdded: return "Attachment Added"
        case .dueDateChanged: return "Due Date Changed"
        case .priorityChanged: return "Priority Changed"
        case .tagAdded: return "Tag Added"
        case .tagRemoved: return "Tag removed"
        }
    }
    
    var icon: String {
        switch self {
        case .reminderCreated: return "plus.circle"
        case .reminderUpdated: return "pencil.circle"
        case .reminderCompleted: return "checkmark.circle"
        case .reminderDeleted: return "trash.circle"
        case .participantAdded: return "person.badge.plus"
        case .participantRemoved: return "person.badge.minus"
        case .permissionChanged: return "key"
        case .commentAdded: return "bubble.left"
        case .attachmentAdded: return "paperclip"
        case .dueDateChanged: return "calendar"
        case .priorityChanged: return "exclamationmark.triangle"
        case .tagAdded: return "tag"
        case .tagRemoved: return "tag.slash"
        }
    }
}

// MARK: - Shared List
@Model
final class SharedList {
    var id: UUID = UUID()
    var listID: UUID = UUID()
    var ownerID: String = ""
    var ownerName: String = ""
    var sharedAt: Date = Date()
    var lastModified: Date = Date()
    var isActive: Bool = true
    
    // Sharing settings
    var allowAddReminders: Bool = true
    var allowEditReminders: Bool = true
    var allowDeleteReminders: Bool = false
    var allowManageParticipants: Bool = false
    
    @Relationship(deleteRule: .cascade) var participants: [ShareParticipant] = []
    @Relationship(deleteRule: .nullify) var list: ReminderList?
    
    init(list: ReminderList, ownerID: String, ownerName: String) {
        self.listID = UUID() // Lists don't have UUIDs by default, might need to add
        self.list = list
        self.ownerID = ownerID
        self.ownerName = ownerName
        self.sharedAt = Date()
        self.lastModified = Date()
    }
}

// MARK: - Comment System
@Model
final class ReminderComment {
    var id: UUID = UUID()
    var content: String = ""
    var authorID: String = ""
    var authorName: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date?
    var isEdited: Bool = false
    var isDeleted: Bool = false
    
    // Mentions and reactions
    var mentions: [String] = [] // User IDs mentioned in comment
    var reactions: Data? // JSON data for emoji reactions
    
    @Relationship(deleteRule: .nullify) var reminder: Reminder?
    @Relationship(deleteRule: .cascade) var replies: [ReminderComment] = []
    @Relationship(deleteRule: .nullify) var parentComment: ReminderComment?
    
    init(content: String, authorID: String, authorName: String, reminder: Reminder) {
        self.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        self.authorID = authorID
        self.authorName = authorName
        self.reminder = reminder
        self.createdAt = Date()
    }
    
    // MARK: - Comment Management
    
    func edit(newContent: String) {
        content = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedAt = Date()
        isEdited = true
    }
    
    func delete() {
        isDeleted = true
        content = "[Deleted]"
        updatedAt = Date()
    }
    
    func addReply(content: String, authorID: String, authorName: String) -> ReminderComment {
        let reply = ReminderComment(content: content, authorID: authorID, authorName: authorName, reminder: reminder!)
        reply.parentComment = self
        replies.append(reply)
        return reply
    }
    
    // MARK: - Reactions
    
    func addReaction(emoji: String, userID: String) {
        var reactions = getReactions()
        reactions[emoji, default: []].append(userID)
        setReactions(reactions)
    }
    
    func removeReaction(emoji: String, userID: String) {
        var reactions = getReactions()
        reactions[emoji]?.removeAll { $0 == userID }
        if reactions[emoji]?.isEmpty == true {
            reactions.removeValue(forKey: emoji)
        }
        setReactions(reactions)
    }
    
    private func getReactions() -> [String: [String]] {
        guard let data = reactions else { return [:] }
        return (try? JSONDecoder().decode([String: [String]].self, from: data)) ?? [:]
    }
    
    private func setReactions(_ reactions: [String: [String]]) {
        self.reactions = try? JSONEncoder().encode(reactions)
    }
}

// MARK: - Team/Workspace
@Model
final class Workspace {
    var id: UUID = UUID()
    var name: String = ""
    var workspaceDescription: String = ""
    var ownerID: String = ""
    var ownerName: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isActive: Bool = true
    
    // Workspace settings
    var isPublic: Bool = false
    var allowGuestAccess: Bool = false
    var maxMembers: Int = 50
    var subscriptionTier: String = "free" // free, pro, team
    
    // Branding
    var logoURL: String?
    var colorScheme: String = "default"
    var customDomain: String?
    
    @Relationship(deleteRule: .cascade) var members: [WorkspaceMember] = []
    @Relationship(deleteRule: .cascade) var sharedLists: [SharedList] = []
    @Relationship(deleteRule: .cascade) var sharedReminders: [SharedReminder] = []
    
    init(name: String, ownerID: String, ownerName: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.ownerID = ownerID
        self.ownerName = ownerName
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Member Management
    
    func addMember(userID: String, email: String, name: String, role: WorkspaceRole) -> WorkspaceMember {
        let member = WorkspaceMember(
            userID: userID,
            email: email,
            name: name,
            role: role,
            workspace: self
        )
        
        members.append(member)
        updatedAt = Date()
        
        return member
    }
    
    func removeMember(_ member: WorkspaceMember) {
        if let index = members.firstIndex(of: member) {
            members.remove(at: index)
            updatedAt = Date()
        }
    }
    
    var activeMembers: [WorkspaceMember] {
        return members.filter { $0.status == .active }
    }
    
    var canAddMembers: Bool {
        return activeMembers.count < maxMembers
    }
}

// MARK: - Workspace Member
@Model
final class WorkspaceMember {
    var id: UUID = UUID()
    var userID: String = ""
    var email: String = ""
    var name: String = ""
    var role: WorkspaceRole = WorkspaceRole.member
    var status: WorkspaceMemberStatus = WorkspaceMemberStatus.pending
    var joinedAt: Date = Date()
    var lastActive: Date?
    var invitedBy: String = ""
    
    // Permissions
    var canCreateLists: Bool = true
    var canShareReminders: Bool = true
    var canInviteMembers: Bool = false
    var canManageWorkspace: Bool = false
    
    @Relationship(deleteRule: .nullify) var workspace: Workspace?
    
    init(userID: String, email: String, name: String, role: WorkspaceRole, workspace: Workspace) {
        self.userID = userID
        self.email = email
        self.name = name
        self.role = role
        self.workspace = workspace
        self.joinedAt = Date()
        
        // Set permissions based on role
        updatePermissionsForRole()
    }
    
    private func updatePermissionsForRole() {
        switch role {
        case .owner:
            canCreateLists = true
            canShareReminders = true
            canInviteMembers = true
            canManageWorkspace = true
        case .admin:
            canCreateLists = true
            canShareReminders = true
            canInviteMembers = true
            canManageWorkspace = false
        case .member:
            canCreateLists = true
            canShareReminders = true
            canInviteMembers = false
            canManageWorkspace = false
        case .guest:
            canCreateLists = false
            canShareReminders = false
            canInviteMembers = false
            canManageWorkspace = false
        }
    }
}

// MARK: - Workspace Enums
enum WorkspaceRole: String, CaseIterable, Codable {
    case owner = "owner"
    case admin = "admin"
    case member = "member"
    case guest = "guest"
    
    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .member: return "Member"
        case .guest: return "Guest"
        }
    }
}

enum WorkspaceMemberStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case active = "active"
    case suspended = "suspended"
    case left = "left"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .active: return "Active"
        case .suspended: return "Suspended"
        case .left: return "Left"
        }
    }
}
