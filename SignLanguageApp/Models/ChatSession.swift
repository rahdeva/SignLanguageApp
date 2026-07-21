//
//  ChatSession.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 21/07/26.
//

import Foundation
import SwiftData

@Model
final class ChatSession {
    @Attribute(.unique) var id: UUID
    var title: String?
    var createdAt: Date
    var endedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage]

    var isActive: Bool { endedAt == nil }
    var messageCount: Int { messages.count }

    init(
        id: UUID = UUID(),
        title: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}
