//
//  ConversationContextService.swift
//  SignLanguageApp
//
//  Created by Antigravity on 21/07/26.
//

import Foundation

/// Builds conversation-context strings for the AI refinement prompts.
/// Keeps a sliding window of recent messages to stay within the
/// on-device Foundation Models token budget (~4K tokens).
struct ConversationContextService {
    
    /// Maximum number of recent messages to include in the context window.
    static let maxContextMessages = 6
    
    /// Formats recent conversation history into a context block for AI prompts.
    /// - Parameters:
    ///   - history: The full conversation history array
    ///   - currentSpeaker: Who is currently speaking (to label perspective correctly)
    /// - Returns: A formatted string of recent conversation turns
    static func buildContextString(
        from history: [Conversation],
        currentSpeaker: ConversationRole
    ) -> String {
        let recent = history.suffix(maxContextMessages)
        guard !recent.isEmpty else { return "" }
        
        var lines: [String] = []
        lines.append("# Conversation History (most recent messages)")
        
        for entry in recent {
            let speaker: String
            switch entry.role {
            case .userSigned, .assistantSpoke:
                speaker = "Teman Tuli"
            case .userSpoke:
                speaker = "Caregiver"
            }
            lines.append("Context: [\(speaker)]: \(entry.message)")
        }
        
        return lines.joined(separator: "\n")
    }
}
