import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - BISINDO Context Corrector using Apple Foundation Models
// Simple standalone Swift file demonstrating prompt engineering.

struct BISINDOTranslator {
    let systemPrompt = """
    You are a translation assistant for BISINDO (Indonesian Sign Language).
    Your task is to take a list of raw Indonesian gesture tokens and reconstruct them into a complete, natural, and grammatically correct INDONESIAN sentence.
    Rules:
    1. Output the final sentence in INDONESIAN.
    2. Add missing words (conjunctions, prepositions, prefixes/suffixes, helping verbs) to make the Indonesian sentence natural.
    3. Retain the original meaning of the gesture tokens.
    4. Output ONLY the corrected Indonesian sentence. Do not include explanations, translation notes, or introductory text.
    """
    
    let examples = [
        (input: ["saya", "makan", "nasi"], output: "Saya sedang makan nasi."),
        (input: ["kamu", "pergi", "mana"], output: "Kamu mau pergi ke mana?"),
        (input: ["tolong", "ambil", "air"], output: "Tolong ambilkan saya air minum."),
        (input: ["saya", "nama", "Budi"], output: "Nama saya Budi."),
        (input: ["saya", "senang"], output: "Saya merasa senang."),
        (input: ["ibu", "rumah", "pulang"], output: "Ibu sudah pulang ke rumah.")
    ]
    
    /// Merges consecutive single-letter tokens separated by space tokens into complete words.
    func preprocessTokens(_ rawTokens: [String]) -> [String] {
        var processed: [String] = []
        var currentWordLetters: [String] = []
        
        for token in rawTokens {
            if token == " " {
                if !currentWordLetters.isEmpty {
                    processed.append(currentWordLetters.joined())
                    currentWordLetters.removeAll()
                }
            } else if token.count == 1 {
                currentWordLetters.append(token)
            } else {
                if !currentWordLetters.isEmpty {
                    processed.append(currentWordLetters.joined())
                    currentWordLetters.removeAll()
                }
                processed.append(token)
            }
        }
        
        if !currentWordLetters.isEmpty {
            processed.append(currentWordLetters.joined())
        }
        
        return processed
    }
    
    /// Construct prompt for LLM
    func buildPrompt(for tokens: [String]) -> String {
        let cleanTokens = preprocessTokens(tokens)
        var prompt = "\(systemPrompt)\n\n"
        prompt += "Examples:\n"
        for example in examples {
            prompt += "Input: \(example.input.joined(separator: ", "))\n"
            prompt += "Output: \(example.output)\n\n"
        }
        prompt += "Now translate and correct this input:\n"
        prompt += "Input: \(cleanTokens.joined(separator: ", "))\n"
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

// MARK: - Global Helper Function

/// Global utility function to translate and correct BISINDO tokens using Apple's Foundation Models on-device.
func checkFM(input: [String]) async throws -> String {
    let translator = BISINDOTranslator()
    return try await translator.translateOnDevice(tokens: input)
}

// MARK: - Execution

@main
struct MainApp {
    static func main() async {
        let rawTokens = ["saya", "rumah", "tidur"]
        
        print("Tokens: \(rawTokens)")
        print("Generating correction...")
        
        do {
            let result = try await checkFM(input: rawTokens)
            print("Result: \"\(result)\"")
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
}
