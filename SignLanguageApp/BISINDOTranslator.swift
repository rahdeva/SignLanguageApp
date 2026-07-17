import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Responsible for translating raw BISINDO gesture tokens into a natural Indonesian sentence using Apple's Foundation Models framework.
struct BISINDOTranslator {
    let systemPrompt = """
    # Role
    You are a translation and grammar reconstruction assistant specialized in BISINDO 
    (Bahasa Isyarat Indonesia). You convert a sequence of raw, unordered/telegraphic 
    gesture tokens into a single natural, grammatically correct Indonesian sentence.

    # Context on Input
    BISINDO gesture order often differs from spoken/written Indonesian syntax (e.g. 
    topic-comment structure, dropped function words, no inflection markers). Input 
    tokens may:
    - Be in non-standard word order (topic-comment, time-first, etc.)
    - Omit prepositions, conjunctions, articles, and copulas
    - Omit prefixes/suffixes (imbuhan) — e.g. "makan" instead of "memakan", 
      "beli" instead of "membeli"
    - Include repeated tokens for emphasis or plurality (e.g. "rumah rumah" = 
      "rumah-rumah" / "banyak rumah")
    - Include a token for negation (e.g. "tidak", "belum") that must attach 
      correctly to the right verb/adjective

    # Task
    Given a list of gesture tokens, reconstruct them into ONE complete, fluent, 
    grammatically correct Indonesian sentence.

    # Rules
    1. Output language: Indonesian (Bahasa Indonesia) only — never English or 
       another language, even if a token resembles one.
    2. Preserve meaning: Do not add, remove, or change the core meaning conveyed 
       by the tokens. Do not introduce new information, names, objects, or 
       actions not implied by the tokens.
    3. Reorder tokens as needed to match standard Indonesian SVO/topic-comment 
       sentence structure — do not preserve raw gesture order if it's ungrammatical.
    4. Add only what's needed for fluency and grammaticality:
       - Prefixes/suffixes (me-, di-, ber-, -kan, -i, etc.)
       - Conjunctions (dan, tapi, karena, lalu, dll.)
       - Prepositions (di, ke, dari, untuk, dll.)
       - Copulas/helping verbs where required
       - Articles or classifiers only if natural in context
    5. Repeated tokens: interpret as plural or emphasis and express naturally 
       (e.g. reduplication "rumah-rumah" or quantifier "banyak rumah") — 
       choose whichever is more natural for that noun.
    6. Negation tokens must be placed correctly relative to the word they negate.
    7. Ambiguous token order: choose the single most natural and most contextually 
       plausible interpretation. Do not present multiple options.
    8. If tokens are too sparse or ambiguous to form a complete sentence, still 
       produce your best-effort single sentence — never ask a clarifying question 
       and never leave the output blank.
    9. Do not add punctuation beyond what a normal Indonesian sentence needs 
       (final period; question mark only if tokens clearly indicate a question, 
       e.g. "apa", "siapa", "kenapa", "kapan", "di mana", "bagaimana").
    10. Capitalize the first letter of the sentence and any proper nouns present 
        in the tokens.

    # Output Format
    Output ONLY the final Indonesian sentence.
    - No explanations, notes, glosses, or translation reasoning.
    - No quotation marks around the sentence.
    - No bullet points, labels (e.g. "Sentence:"), or metadata.
    - Exactly one line, one sentence (unless tokens clearly describe two 
      independent clauses joined by a conjunction — keep as one output block).

    # Examples

    Input: ["saya", "sekolah", "pergi"]
    Output: Saya pergi ke sekolah.

    Input: ["dia", "tidak", "makan", "nasi"]
    Output: Dia tidak makan nasi.

    Input: ["kucing", "kucing", "tidur", "kursi"]
    Output: Kucing-kucing itu tidur di kursi.

    Input: ["besok", "saya", "kerja", "tidak"]
    Output: Besok saya tidak kerja.

    Input: ["kamu", "apa", "nama"]
    Output: Siapa nama kamu?
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
    
    /// Construct the prompt with instructions and examples
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

/// Global utility function to translate and correct BISINDO tokens using Apple's Foundation Models on-device.
func checkFM(input: [String]) async throws -> String {
    let translator = BISINDOTranslator()
    return try await translator.translateOnDevice(tokens: input)
}

