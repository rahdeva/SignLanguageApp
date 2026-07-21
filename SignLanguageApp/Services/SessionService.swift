//
//  SessionService.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 21/07/26.
//

import Foundation
import SwiftData

@MainActor
final class SessionService {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - Sessions

    func createSession(title: String? = nil) -> ChatSession {
        let session = ChatSession(title: title)
        container.mainContext.insert(session)
        try? container.mainContext.save()
        return session
    }

    func endSession(_ session: ChatSession) {
        session.endedAt = .now
        try? container.mainContext.save()
    }

    func deleteSession(_ session: ChatSession) {
        container.mainContext.delete(session)
        try? container.mainContext.save()
    }

    func allSessions() -> [ChatSession] {
        let descriptor = FetchDescriptor<ChatSession>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? container.mainContext.fetch(descriptor)) ?? []
    }

    func activeSession() -> ChatSession? {
        let descriptor = FetchDescriptor<ChatSession>(
            predicate: #Predicate { $0.endedAt == nil }
        )
        return try? container.mainContext.fetch(descriptor).first
    }

    // MARK: - Messages

    func messages(for session: ChatSession) -> [ChatMessage] {
        session.messages.sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    func appendMessage(to session: ChatSession, content: String, role: MessageRole) -> ChatMessage {
        let message = ChatMessage(content: content, role: role)
        message.session = session
        session.messages.append(message)
        try? container.mainContext.save()
        return message
    }

    func deleteMessage(_ message: ChatMessage) {
        container.mainContext.delete(message)
        try? container.mainContext.save()
    }
}
