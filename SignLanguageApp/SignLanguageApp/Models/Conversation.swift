//
//  Conversation.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import Foundation

/// Who said what — used to build the conversation history log.
enum ConversationRole: String, Sendable, Codable {
    case userSigned, userSpoke, assistantSpoke

    var label: String {
        switch self {
        case .userSigned: "You (Sign)"
        case .userSpoke: "You (Speech)"
        case .assistantSpoke: "Assistant"
        }
    }
}

/// A single entry in the bidirectional conversation timeline.
struct Conversation: Identifiable, Sendable {
    let id: UUID
    let message: String
    let role: ConversationRole
    let timestamp: Date

    init(
        id: UUID = UUID(),
        message: String,
        role: ConversationRole,
        timestamp: Date = .now
    ) {
        self.id = id
        self.message = message
        self.role = role
        self.timestamp = timestamp
    }
}
