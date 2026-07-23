//
//  SignLanguageFMConvert.swift
//  
//
//  Created by Dimas Prihady Setyawan on 18/07/26.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Responsible for translating raw BISINDO gesture tokens into a natural Indonesian sentence using Apple's Foundation Models framework.
struct BISINDOTranslator {
    
    let systemPrompt = """
# Role & Task (System Language: English)
You are a BISINDO (Indonesian Sign Language) translation assistant.
Convert raw input gesture tokens into a single, natural, grammatically correct Indonesian sentence.

# Target Output Format
ALWAYS format your final output using this exact envelope:
Deaf friend says: "<Indonesian sentence>"

# Rules
1. Output language MUST be natural Bahasa Indonesia.
2. If Context contains a question from the Caregiver (e.g. "Kamu sedang apa?"), interpret sign tokens as a direct contextual response to that question.
3. Reorder tokens and add natural verbs/conjunctions as needed for correct grammar.
4. Output ONLY the format: Deaf friend says: "<Indonesian sentence>".
5. Domain Context: This is a friendly accessibility translation app for everyday sign language communication.

# Examples

Context: [Caregiver]: Kamu sedang apa?
Input: ["saya", "dengar", "motor"]
Output: Deaf friend says: "Saya sedang mendengar motor."

Context: [Caregiver]: Kamu sudah makan belum?
Input: ["saya", "lagi"]
Output: Deaf friend says: "Saya sedang makan."

Context: [Caregiver]: Kamu mau pergi ke mana?
Input: ["saya", "rumah", "teman"]
Output: Deaf friend says: "Saya mau ke rumah teman."

Input: ["saya", "belajar", "motor", "merah"]
Output: Deaf friend says: "Saya sedang belajar motor merah."
"""
    
    var systemPromptIndonesian: String { systemPrompt }

    var systemPromptEnglish: String {
        """
# Role & Task (System Language: English)
You are an English-guided AI translation assistant specialized in BISINDO (Indonesian Sign Language).
You process a sequence of raw gesture-recognition tokens into a single, natural, grammatically correct English sentence.

# Target Output Format
ALWAYS format your final output using this exact envelope:
Deaf friend says: "<English sentence>"

# Vocabulary Reference (Indonesian token -> English meaning):
Air (Water), Belajar (Study/Learn), Cari (Look for), Hari (Day), Ingat (Remember), Lagi (Currently/Ongoing), Maaf (Sorry), Makan (Eat), Motor (Motorcycle), Saya (I/Me), Terima kasih (Thank you), Tuli (Deaf), Apa (What), Siapa (Who), Kapan (When), Di mana (Where), Mengapa (Why), Bagaimana (How), Merah (Red), Kuning (Yellow), Hijau (Green), Hitam (Black), Dengar (Listen/Hear), Berangkat (Depart/Leave), Datang (Come/Arrive), Teman (Friend), Keluarga (Family), Rumah (House/Home), Pagi (Morning), Siang (Afternoon), Sore (Late Afternoon), Malam (Night).

# Rules
1. Output language MUST be natural English.
2. If Context contains a question from the Caregiver (e.g. "What are you doing?"), interpret the sign tokens as a direct contextual response to that question.
3. Preserve the core meaning of the input tokens.
4. Output ONLY the format: Deaf friend says: "<English sentence>".

# Examples

Context: [Caregiver]: What are you doing?
Input: ["saya", "dengar", "motor"]
Output: Deaf friend says: "I am listening to a motorcycle."

Context: [Caregiver]: Have you eaten?
Input: ["saya", "lagi"]
Output: Deaf friend says: "I am currently eating."

Context: [Caregiver]: Where are you going?
Input: ["saya", "rumah", "teman"]
Output: Deaf friend says: "I am going to a friend's house."

Input: ["saya", "lagi", "belajar", "motor"]
Output: Deaf friend says: "I am learning to ride a motorcycle."
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
    
    /// Strips numeric ID prefixes (e.g. "26_Keluarga" to "Keluarga")
    func stripLabelID(_ rawLabel: String) -> String {
        if let firstUnderscore = rawLabel.firstIndex(of: "_") {
            let prefix = rawLabel[..<firstUnderscore]
            if prefix.allSatisfy({ $0.isNumber }) {
                return String(rawLabel[rawLabel.index(after: firstUnderscore)...])
            }
        }
        return rawLabel
    }
    
    /// Cleans raw tokens by stripping numeric ID prefixes and lowercasing.
    func preprocessTokens(_ rawTokens: [String]) -> [String] {
        return rawTokens.map { stripLabelID($0).lowercased() }
    }
    
    /// Construct the user prompt for LanguageModelSession.
    func buildPrompt(for tokens: [String], conversationContext: String = "", targetLanguage: AppLanguage = .indonesian) -> String {
        let instructions = promptInstructions(for: targetLanguage)
        let cleanTokens = preprocessTokens(tokens)
        
        var prompt = "\(instructions)\n\n"
        prompt += "Task: Translate gesture tokens into a sentence based on context.\n"
        if !conversationContext.isEmpty {
            prompt += """
\(conversationContext)

Use the conversation history above to understand context.
"""
        }
        prompt += "Input: \(cleanTokens.joined(separator: ", "))\n"
        prompt += "Output:"
        return prompt
    }
    
    /// Corrects BISINDO tokens using Apple Intelligence on-device model
    func translateOnDevice(
        tokens: [String], 
        conversationContext: String = "",
        targetLanguage: AppLanguage = .indonesian
    ) async throws -> String {
        let prompt = buildPrompt(for: tokens, conversationContext: conversationContext, targetLanguage: targetLanguage)
        #if canImport(FoundationModels)
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        guard model.isAvailable else {
            throw NSError(
                domain: "BISINDOTranslator",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence model is not available or not downloaded yet. Please verify device settings."]
            )
        }
        
        // Pass a simple English system instruction to bypass language-support pre-flight checks on iOS
        let simpleInstructions = "You are a helpful translation assistant."
        let session = LanguageModelSession(model: model, instructions: simpleInstructions)
        let response = try await session.respond(to: prompt)
        let rawContent = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.extractSentence(from: rawContent)
        #else
        throw NSError(
            domain: "BISINDOTranslator",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "FoundationModels framework is not supported on this platform/SDK."]
        )
        #endif
    }
    
    /// Extracts the inner sentence from the model output.
    static func extractSentence(from rawOutput: String) -> String {
        let trimmed = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Match Deaf friend says: "..." or "..."
        if let prefixRange = trimmed.range(of: "Deaf friend says:", options: .caseInsensitive) {
            let substring = String(trimmed[prefixRange.upperBound...])
            return substring.trimmingCharacters(in: CharacterSet(charactersIn: " \"“'\n\r"))
        }
        
        return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: " \"“'\n\r"))
    }
}

/// Global utility function to translate and correct BISINDO tokens using Apple's Foundation Models on-device.
func checkFM(
    input: [String], 
    conversationContext: String = "",
    targetLanguage: AppLanguage = .indonesian
) async throws -> String {
    let translator = BISINDOTranslator()
    return try await translator.translateOnDevice(
        tokens: input, 
        conversationContext: conversationContext,
        targetLanguage: targetLanguage
    )
}

/// Manages streaming ML model predictions to build a clean token sequence.
class GestureStreamPipeline {
    private var detectedWords: [String] = []
    private var lastAddedWord: String?
    private let confidenceThreshold: Double
    
    init(confidenceThreshold: Double = 0.40) {
        self.confidenceThreshold = confidenceThreshold
    }
    
    /// Call this when the ML model outputs a prediction.
    func handlePrediction(label: String, probabilities: [String: Double]) {
        guard let probability = probabilities[label], probability >= confidenceThreshold else {
            return
        }
        
        let translator = BISINDOTranslator()
        let cleanWord = translator.stripLabelID(label)
        
        // Debounce: ignore consecutive duplicates
        if cleanWord != lastAddedWord {
            detectedWords.append(cleanWord)
            lastAddedWord = cleanWord
        }
    }
    
    /// Retrieves the accumulated words.
    func getTokens() -> [String] {
        return detectedWords
    }
    
    /// Resets the stream buffer for the next sentence.
    func reset() {
        detectedWords.removeAll()
        lastAddedWord = nil
    }
}
