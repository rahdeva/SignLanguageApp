import Foundation

struct Transcription: Identifiable, Sendable {
    let id: UUID
    let text: String
    let timestamp: Date
    let isFinal: Bool

    init(id: UUID = UUID(), text: String, timestamp: Date = .now, isFinal: Bool = false) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.isFinal = isFinal
    }
}
