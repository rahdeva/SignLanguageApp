import Foundation

enum ConversationRole: String, Sendable, Codable {
    case userSigned, userSpoke, assistantSpoke
}

struct Conversation: Identifiable, Sendable {
    let id: UUID
    let message: String
    let role: ConversationRole
    let timestamp: Date

    init(id: UUID = UUID(), message: String, role: ConversationRole, timestamp: Date = .now) {
        self.id = id
        self.message = message
        self.role = role
        self.timestamp = timestamp
    }
}
