import Foundation

struct SignPrediction: Identifiable, Sendable {
    let id: UUID
    let gestureLabel: String
    let confidence: Float
    let timestamp: Date
    let rawOutput: [String: Float]

    init(id: UUID = UUID(), gestureLabel: String, confidence: Float, timestamp: Date = .now, rawOutput: [String: Float] = [:]) {
        self.id = id
        self.gestureLabel = gestureLabel
        self.confidence = confidence
        self.timestamp = timestamp
        self.rawOutput = rawOutput
    }
}
