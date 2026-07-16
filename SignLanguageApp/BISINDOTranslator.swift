import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Responsible for translating raw BISINDO gesture tokens into a natural Indonesian sentence using Apple's Foundation Models framework.
struct BISINDOTranslator {
    let systemPrompt = """
    You are a translation assistant for BISINDO (Indonesian Sign Language).
    Your task is to take a list of raw Indonesian gesture tokens and reconstruct them into a complete, natural, and grammatically correct INDONESIAN sentence.
    Rules:
    1. Output the final sentence in INDONESIAN.
    2. Add missing words (conjunctions, prepositions, prefixes/suffixes, helping verbs) to make the Indonesian sentence natural and grammatically correct.
    3. Retain the original meaning of the gesture tokens.
    4. Output ONLY the corrected Indonesian sentence. Do not include explanations, translation notes, or introductory text.
    """
    
    let examples = [
        (input: ["saya", "makan", "nasi"], output: "Saya sedang makan nasi."),
        (input: ["kamu", "pergi", "mana"], output: "Kamu mau pergi ke mana?"),
        (input: ["tolong", "ambil", "air"], output: "Tolong ambilkan saya air minum."),
        (input: ["saya", "sakit", "kepala"], output: "Kepala saya terasa sakit."),
        (input: ["ibu", "rumah", "pulang"], output: "Ibu sudah pulang ke rumah.")
    ]
    
    /// Construct the prompt with instructions and examples
    func buildPrompt(for tokens: [String]) -> String {
        var prompt = "\(systemPrompt)\n\n"
        prompt += "Examples:\n"
        for example in examples {
            prompt += "Input: \(example.input.joined(separator: ", "))\n"
            prompt += "Output: \(example.output)\n\n"
        }
        prompt += "Now translate and correct this input:\n"
        prompt += "Input: \(tokens.joined(separator: ", "))\n"
        prompt += "Output:"
        return prompt
    }
    
    /// Corrects BISINDO tokens using Apple Intelligence on-device model
    func translateOnDevice(tokens: [String]) async throws -> String {
        let prompt = buildPrompt(for: tokens)
        
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw NSError(
                domain: "BISINDOTranslator",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence model is not available or not downloaded yet. Please verify device settings."]
            )
        }
        
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        #else
        throw NSError(
            domain: "BISINDOTranslator",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "FoundationModels framework is not supported on this platform/SDK."]
        )
        #endif
    }
}
