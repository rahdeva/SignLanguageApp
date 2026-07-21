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

    func label(for language: AppLanguage) -> String {
        switch self {
        case .userSigned:
            return language == .indonesian ? "Anda (Isyarat)" : "You (Sign)"
        case .userSpoke:
            return language == .indonesian ? "Caregiver (Suara)" : "Caregiver (Speech)"
        case .assistantSpoke:
            return language == .indonesian ? "Teman Tuli" : "Deaf's Friend"
        }
    }

    var label: String {
        switch self {
        case .userSigned: "Anda (Isyarat)"
        case .userSpoke: "Caregiver (Suara)"
        case .assistantSpoke: "Asisten"
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
