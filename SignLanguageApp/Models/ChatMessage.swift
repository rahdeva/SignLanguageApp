//
//  ChatMessage.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 21/07/26.
//

import Foundation
import SwiftData

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var content: String
    var role: MessageRole
    var createdAt: Date
    var session: ChatSession?

    init(
        id: UUID = UUID(),
        content: String,
        role: MessageRole,
        createdAt: Date = .now
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.createdAt = createdAt
    }
}
