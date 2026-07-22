//
//  PracticeHistoryItem.swift
//  SignLanguageApp
//
//  Created by Antigravity on 23/07/26.
//

import Foundation
import SwiftData

/// SwiftData model for persisting practice and sign conversation sessions.
@Model
final class PracticeHistoryItem {
    @Attribute(.unique) var id: UUID
    var date: Date
    var question: String
    var targetTokens: [String]
    var completedCount: Int
    var durationSeconds: Int
    var scoreRawValue: String

    init(
        id: UUID = UUID(),
        date: Date = .now,
        question: String,
        targetTokens: [String],
        completedCount: Int,
        durationSeconds: Int,
        scoreRawValue: String
    ) {
        self.id = id
        self.date = date
        self.question = question
        self.targetTokens = targetTokens
        self.completedCount = completedCount
        self.durationSeconds = durationSeconds
        self.scoreRawValue = scoreRawValue
    }
}
