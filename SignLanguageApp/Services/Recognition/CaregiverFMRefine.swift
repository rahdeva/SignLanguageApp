//
//  CaregiverFMRefine.swift
//  SignLanguageApp
//
//  Created by Antigravity on 21/07/26.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Refines caregiver speech transcription using Apple's Foundation Models,
/// making it clearer for the deaf friend to read, while preserving the
/// original meaning. Uses conversation context to generate relevant responses.
struct CaregiverSpeechRefiner {
    
    let systemPrompt = """
    # Role & Task (System Language: English)
    You are an English-guided communication assistant in a two-way conversation between a 
    Caregiver (hearing person) and a Teman Tuli (Deaf Friend who uses BISINDO 
    sign language). Your job is to take the Caregiver's raw speech transcription 
    and refine it into clear, concise Indonesian text that is easy for the Deaf 
    Friend to read on screen.

    # Rules
    1. Output language: Indonesian (Bahasa Indonesia) only.
    2. Preserve the original meaning — do not add information the caregiver 
       did not say.
    3. Fix speech recognition errors and incomplete sentences where the 
       intent is clear from context.
    4. Simplify overly complex or rambling speech into clear, direct sentences.
    5. If the caregiver's speech is a question, keep it as a question.
    6. If the caregiver's speech is a response to something the Deaf Friend 
       said, make sure the refined text reads as a natural continuation of 
       the conversation.
    7. Remove filler words (um, uh, eh, hmm, ya kan, gitu, etc.) and 
       false starts.
    8. Keep sentences short and easy to read — the Deaf Friend needs to 
       read this quickly on a small screen.
    9. Use proper punctuation (question marks for questions, periods for 
       statements).
    10. Output ONLY the refined Indonesian sentence(s). No explanations, 
        notes, or formatting.

    # Output Format
    Output ONLY the refined sentence(s). No labels, no quotes, no bullet 
    points.

    # Examples

    Raw speech: "Eh... jadi begini ya, mm... tadi saya cuma mau nanya, kamu eh... sudah makan siang belum ya?"
    Output: Apakah kamu sudah makan siang?

    Raw speech: "Nanti sore itu kamu mau pergi ke mana ya kira-kira?"
    Output: Nanti sore kamu mau pergi ke mana?

    Context: [Teman Tuli]: Saya di rumah teman.
    Raw speech: "Oh kamu lagi di rumah teman ya, terus nanti pulang jam berapa?"
    Output: Kamu sedang di rumah teman. Nanti pulang jam berapa?

    Raw speech: "Oh begitu ya, ya sudah tidak apa-apa, makasih ya"
    Output: Oh begitu, tidak apa-apa. Terima kasih.
    """
    
    /// Builds the prompt with conversation context and raw speech
    func buildPrompt(
        rawSpeech: String,
        conversationContext: String = ""
    ) -> String {
        var prompt = ""
        
        if !conversationContext.isEmpty {
            prompt += """
            \(conversationContext)
            
            The conversation above is the recent exchange between the Caregiver 
            and Deaf Friend. Use it to understand the flow of conversation.
            
            """
        }
        
        prompt += """
        Now refine the following raw speech transcription from the Caregiver:
        
        Raw speech: "\(rawSpeech)"
        
        Refined output:
        """
        
        return prompt
    }
    
    /// Refines caregiver speech using Apple Intelligence on-device model
    func refineOnDevice(
        rawSpeech: String,
        conversationContext: String = ""
    ) async throws -> String {
        let prompt = buildPrompt(
            rawSpeech: rawSpeech,
            conversationContext: conversationContext
        )
        
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw NSError(
                domain: "CaregiverSpeechRefiner",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: 
                    "Apple Intelligence model is not available."]
            )
        }
        
        let session = LanguageModelSession(instructions: systemPrompt)
        let response = try await session.respond(to: prompt)
        let rawContent = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.extractSentence(from: rawContent)
        #else
        throw NSError(
            domain: "CaregiverSpeechRefiner",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: 
                "FoundationModels framework not supported."]
        )
        #endif
    }
    
    /// Extracts the inner Indonesian sentence from the model output.
    static func extractSentence(from rawOutput: String) -> String {
        let trimmed = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let prefixRange = trimmed.range(of: "Caregiver says:", options: .caseInsensitive) {
            let substring = String(trimmed[prefixRange.upperBound...])
            return substring.trimmingCharacters(in: CharacterSet(charactersIn: " \"“'\n\r"))
        }
        
        return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: " \"“'\n\r"))
    }
}

/// Global utility function to refine caregiver speech
func refineCaregiverSpeech(
    rawSpeech: String, 
    conversationContext: String = ""
) async throws -> String {
    let refiner = CaregiverSpeechRefiner()
    return try await refiner.refineOnDevice(
        rawSpeech: rawSpeech, 
        conversationContext: conversationContext
    )
}
