//
//  PracticeRecord.swift
//  SignLanguageApp
//
//  Created by Antigravity on 23/07/26.
//

import Foundation

/// Structured record of a completed practice/conversation session.
struct PracticeRecord: Identifiable, Sendable, Equatable {
    let id: UUID
    let date: Date
    let question: String
    let targetTokens: [String]
    let completedCount: Int
    let durationSeconds: Int

    init(
        id: UUID = UUID(),
        date: Date = .now,
        question: String,
        targetTokens: [String],
        completedCount: Int,
        durationSeconds: Int
    ) {
        self.id = id
        self.date = date
        self.question = question
        self.targetTokens = targetTokens
        self.completedCount = completedCount
        self.durationSeconds = durationSeconds
    }
}
