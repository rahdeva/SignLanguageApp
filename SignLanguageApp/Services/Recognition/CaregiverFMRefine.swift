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
2. Preserve the original meaning — do not add information the caregiver did not say.
3. Fix speech recognition errors and incomplete sentences where the intent is clear from context.
4. Simplify overly complex or rambling speech into clear, direct sentences.
5. If the caregiver's speech is a question, keep it as a question.
6. Remove filler words (um, uh, eh, hmm, ya kan, gitu, etc.) and false starts.
7. Output format: Caregiver says: "<Indonesian sentence>"

# Examples

Raw speech: "Eh... jadi begini ya, mm... tadi saya cuma mau nanya, kamu eh... sudah makan siang belum ya?"
Output: Caregiver says: "Apakah kamu sudah makan siang?"

Raw speech: "Nanti sore itu kamu mau pergi ke mana ya kira-kira?"
Output: Caregiver says: "Nanti sore kamu mau pergi ke mana?"
"""
    
    var systemPromptIndonesian: String { systemPrompt }

    var systemPromptEnglish: String {
        """
# Role & Task (System Language: English)
You are an English-guided communication assistant in a two-way conversation between a 
Caregiver (hearing person) and a Teman Tuli (Deaf Friend who uses BISINDO sign language). 
Your job is to take the Caregiver's raw speech transcription and refine it into clear, 
concise English text for the Deaf Friend to read on screen.

# Rules
1. Output language MUST be English.
2. Preserve original meaning — do not add unstated facts.
3. Remove filler words (um, uh, eh, etc.) and false starts.
4. Output format: Caregiver says: "<English sentence>"

# Examples

Raw speech: "Um, so yeah... I just wanted to ask, what are you doing right now?"
Output: Caregiver says: "What are you doing right now?"

Raw speech: "Eh... jadi begini ya, mm... tadi saya cuma mau nanya, kamu eh... sudah makan siang belum ya?"
Output: Caregiver says: "Have you eaten lunch yet?"
"""
    }

    func promptInstructions(for targetLanguage: AppLanguage) -> String {
        switch targetLanguage {
        case .english:
            return systemPromptEnglish
        case .indonesian:
            return systemPromptIndonesian
        }
    }
    
    /// Builds the prompt with conversation context and raw speech
    func buildPrompt(
        rawSpeech: String,
        conversationContext: String = "",
        targetLanguage: AppLanguage = .indonesian
    ) -> String {
        let instructions = promptInstructions(for: targetLanguage)
        var prompt = "\(instructions)\n\n"
        
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
        conversationContext: String = "",
        targetLanguage: AppLanguage = .indonesian
    ) async throws -> String {
        let prompt = buildPrompt(
            rawSpeech: rawSpeech,
            conversationContext: conversationContext,
            targetLanguage: targetLanguage
        )
        
        #if canImport(FoundationModels)
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        guard model.isAvailable else {
            throw NSError(
                domain: "CaregiverSpeechRefiner",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: 
                    "Apple Intelligence model is not available."]
            )
        }
        
        // Pass a simple English system instruction to bypass language-support pre-flight checks on iOS
        let simpleInstructions = "You are a helpful communication assistant."
        let session = LanguageModelSession(model: model, instructions: simpleInstructions)
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
    
    /// Extracts the inner sentence from the model output.
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
    conversationContext: String = "",
    targetLanguage: AppLanguage = .indonesian
) async throws -> String {
    let refiner = CaregiverSpeechRefiner()
    return try await refiner.refineOnDevice(
        rawSpeech: rawSpeech, 
        conversationContext: conversationContext,
        targetLanguage: targetLanguage
    )
}
