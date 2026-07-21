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
        guard !history.isEmpty else { return "" }
        
        switch currentSpeaker {
        case .userSigned:
            // Deaf Friend is signing: find the last question/message from the Caregiver
            if let lastCaregiverMessage = history.last(where: { $0.role == .userSpoke }) {
                return "Context: [Caregiver]: \(lastCaregiverMessage.message)"
            }
        case .userSpoke, .assistantSpoke:
            // Caregiver is speaking: find the last message from the Deaf Friend
            if let lastDeafMessage = history.last(where: { $0.role == .userSigned || $0.role == .assistantSpoke }) {
                return "Context: [Teman Tuli]: \(lastDeafMessage.message)"
            }
        }
        
        return ""
    }
}
