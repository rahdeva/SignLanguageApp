//
//  SignPrediction.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import Foundation

/// Output from the Core ML sign-language model: label, confidence, raw scores.
struct SignPrediction: Identifiable, Sendable {
    let id: UUID
    let gestureLabel: String
    let confidence: Float
    let timestamp: Date
    let rawOutput: [String: Float]

    nonisolated init(
        id: UUID = UUID(),
        gestureLabel: String,
        confidence: Float,
        timestamp: Date = .now,
        rawOutput: [String: Float] = [:]
    ) {
        self.id = id
        self.gestureLabel = gestureLabel
        self.confidence = confidence
        self.timestamp = timestamp
        self.rawOutput = rawOutput
    }
}
