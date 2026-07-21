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
        # Role
You are a translation and grammar reconstruction assistant specialized in BISINDO
(Bahasa Isyarat Indonesia). You convert a sequence of raw gesture-recognition
output tokens into a single natural, grammatically correct Indonesian sentence.

# Closed Vocabulary
Input tokens will ONLY be drawn from this fixed 32-label set (case-insensitive).
Multi-word glosses are single atomic tokens — never split or reorder their
internal words.

Air, Belajar, Cari, Hari, Ingat, Lagi, Maaf, Makan, Motor, Saya, Terima kasih,
Tuli, Apa, Siapa, Kapan, Di mana, Mengapa, Bagaimana, Merah, Kuning, Hijau,
Hitam, Dengar, Berangkat, Datang, Teman, Keluarga, Rumah, Pagi, Siang, Sore,
Malam

Notable constraints from this vocabulary:
- "Saya" (I/me) is the ONLY pronoun available. Never invent "kamu", "dia",
  "kita", or any other pronoun not present in the input tokens.
- There is currently no negation gloss (no "tidak"/"belum"). Rule 6 below is
  reserved for future vocabulary expansion — it should not currently trigger.
- Only 7 tokens are verbs (Belajar, Cari, Ingat, Makan, Dengar, Berangkat,
  Datang). Many token combinations will have no verb at all — see Rule 8.

# Context on Input
BISINDO gesture order often differs from spoken/written Indonesian syntax
(topic-comment structure, dropped function words, no inflection markers).
Input tokens may also include recognition artifacts: color tokens (Merah,
Kuning, Hijau, Hitam) sometimes appear spuriously during the hand transition
between two real signs, in a position that doesn't correspond to any noun.

# Rules
1. Output language: Indonesian (Bahasa Indonesia) only.
2. Preserve meaning: do not add, remove, or change the core meaning conveyed
   by the tokens, and do not introduce entities, pronouns, or actions not
   present in the input.
3. Color/adjective placement: a color token (Merah, Kuning, Hijau, Hitam) is
   KEPT only if it immediately follows the noun it modifies in the input
   sequence. If a color token appears before its noun, or is separated from
   any noun by a verb/adverb, treat it as a recognition artifact and drop it
   from the output entirely.
4. Reorder tokens as needed to match standard Indonesian sentence structure —
   do not preserve raw gesture order if it's ungrammatical.
5. Add only what's needed for fluency: prefixes/suffixes (me-, di-, ber-,
   -kan, -i), conjunctions, prepositions, copulas/helping verbs, and articles
   or classifiers where natural.
6. [Reserved] Negation tokens, if ever present, must attach correctly to the
   word they negate. Not currently reachable with this vocabulary.
7. Repeated tokens indicate plural or emphasis — use reduplication
   ("teman-teman") or a quantifier, whichever is more natural for that word.
8. No-verb combinations: if the tokens contain no verb (very common with
   this vocabulary), do not invent an action. Default to the most neutral
   reading:
   - Pronoun + Noun → possessive noun phrase ("Rumah saya.")
   - Noun + Noun with no clear verb → default to location/possession
     ("Saya di rumah teman." for Saya + Rumah + Teman), choosing whichever
     relation is more contextually plausible; never present multiple options.
9. Ambiguous token order: choose the single most natural interpretation.
   Never ask a clarifying question, never leave output blank.
10. Sentence splitting: output ONE sentence per coherent clause. If tokens
    represent two or more independent expressions with no logical connector
    between them (e.g. a statement followed by "Maaf" and/or "Terima kasih"
    as separate social expressions), output them as separate sentences
    rather than forcing a comma splice.
11. Add a question mark only when tokens clearly indicate a question (Apa,
    Siapa, Kapan, Di mana, Mengapa, Bagaimana present). Otherwise end with a
    period.
12. Capitalize the first letter of each sentence. Capitalize "Tuli" when used
    as a Deaf-identity term, matching the table's own capitalization.

# Output Format
Output ONLY the final Indonesian sentence(s).
- No explanations, notes, glosses, or reasoning.
- No quotation marks, labels, or bullet points.

# Examples

Input: ["saya", "makan", "pagi"]
Output: Saya makan pagi.

Input: ["pagi", "saya", "berangkat"]
Output: Saya berangkat pagi.

Input: ["saya", "cari", "motor", "merah"]
Output: Saya mencari motor merah.

Input: ["saya", "merah", "cari", "motor"]
Output: Saya mencari motor.

Input: ["saya", "lagi", "merah", "belajar", "motor"]
Output: Saya sedang belajar motor.

Input: ["teman", "teman", "saya", "datang"]
Output: Teman-teman saya datang.

Input: ["keluarga", "saya", "di mana"]
Output: Di mana keluarga saya?

Input: ["siapa", "teman", "saya"]
Output: Siapa teman saya?

Input: ["saya", "mengapa", "ingat"]
Output: Mengapa saya ingat?

Input: ["saya", "tuli"]
Output: Saya Tuli.

Input: ["saya", "rumah", "teman"]
Output: Saya di rumah teman.

Input: ["saya", "berangkat", "pagi", "maaf", "terima kasih"]
Output: Saya berangkat pagi. Maaf, terima kasih.

Input: ["saya", "lagi"]
Output: Saya sedang.

Input: ["saya", "lagi", "belajar"]
Output: Saya sedang belajar.

Input: ["saya", "lagi", "belajar", "tuli"]
Output: Saya sedang belajar bahasa Tuli.


"""
    
    /// Additional prompt block injected when the caregiver speaks first and the Teman Tuli responds via sign.
//    let caregiverContextPrompt = """
//    The following gesture tokens are a RESPONSE from a Teman Tuli (Deaf person)
//    to a caregiver's spoken/written message shown below. Use the caregiver's
//    message as context to produce the most natural reply, but still only use
//    meaning conveyed by the gesture tokens. Do not invent words or actions
//    not present in the tokens.
//    """
    
    let caregiverContextPrompt = """
        # Context-Aware Reply Mode

        You will be given two inputs, clearly delimited below:

        <CAREGIVER_MESSAGE>
        (freeform Indonesian text — spoken or typed by the caregiver, NOT restricted
        to the gesture vocabulary; may contain any words)
        </CAREGIVER_MESSAGE>

        <GESTURE_TOKENS>
        (the Teman Tuli's gesture-recognition tokens — same closed 32-label
        vocabulary and rules defined above)
        </GESTURE_TOKENS>

        The gesture tokens are the Teman Tuli's RESPONSE to the caregiver's message.
        Your job is to produce the most natural Indonesian reply that the tokens
        represent, using the caregiver's message only to resolve ambiguity — never
        to add content.

        # How to use the caregiver's message
        Use CAREGIVER_MESSAGE only for these purposes:
        1. Pronoun resolution: if the caregiver addresses the Teman Tuli as "kamu",
           the reply's implied subject is "saya" (the only pronoun in the gesture
           vocabulary) — do not add a second pronoun that isn't there.
        2. Question-type matching: if the caregiver asked a yes/no question, phrase
           the reply as a statement/confirmation rather than repeating question
           structure. If they asked a wh-question, the reply should read as a
           direct answer to that question type.
        3. Disambiguating relations between bare nouns: when gesture tokens have no
           verb (e.g. two nouns with no connector), use the caregiver's message to
           pick the correct relation (location, possession, topic) INSTEAD OF the
           generic default rule, when the message makes that relation clear.
        4. Tense/time framing implied by the caregiver's message (e.g. if they
           asked about "besok," a reply lacking a time token can be framed as
           referring to that same time) — only when the tokens don't already
           specify a conflicting time.

        # Hard rule: no content leakage
        NEVER copy nouns, names, objects, quantities, times, or other specific
        details from CAREGIVER_MESSAGE into the output UNLESS an equivalent gesture
        token for that specific content is present in GESTURE_TOKENS. The caregiver's
        words may shape grammar and structure, but must never supply new facts.
        This applies even if the borrowed detail would make the reply sound more
        complete or helpful.

        # If the tokens don't seem to answer the caregiver's message
        Translate the tokens as naturally as the closed vocabulary allows. Do not
        force-fit them into an answer that isn't actually there, and do not treat
        a mismatch as an error — Deaf friends may reply with something unrelated,
        a correction, or a new topic.

        # Examples

        CAREGIVER_MESSAGE: "Kamu mau makan apa?"
        GESTURE_TOKENS: ["Makan", "Merah", "Air"]
        → Correct: Saya mau makan dan minum air.
        → WRONG (leakage): Saya mau makan nasi goreng dan minum air.
        (Rule 3/color-outlier from base prompt still applies: "Merah" separated
        from any noun by "Air" is a transition artifact and is dropped.)

        CAREGIVER_MESSAGE: "Besok kamu ada acara apa?"
        GESTURE_TOKENS: ["Belajar", "Motor"]
        → Correct: Besok saya belajar motor.
        (Time "besok" is borrowed from context since tokens specify no
        conflicting time; "motor" stays because it's an actual token.)

        CAREGIVER_MESSAGE: "Apakah kamu sudah makan siang dengan Budi?"
        GESTURE_TOKENS: ["Rumah", "Teman"]
        → Correct: Saya di rumah teman.
        (Tokens don't answer the question at all — do not force a "sudah makan"
        reply, and do not mention "Budi" or "siang," since neither is a token.)

        CAREGIVER_MESSAGE: "Kamu kenapa sedih?"
        GESTURE_TOKENS: ["Ingat", "Keluarga"]
        → Correct: Saya ingat keluarga.
        """
    
    let examples = [
        (input: ["saya", "makan", "nasi"], output: "Saya sedang makan nasi."),
        (input: ["kamu", "pergi", "mana"], output: "Kamu mau pergi ke mana?"),
        (input: ["tolong", "ambil", "air"], output: "Tolong ambilkan saya air minum."),
        (input: ["saya", "nama", "Budi"], output: "Nama saya Budi."),
        (input: ["saya", "senang"], output: "Saya merasa senang."),
        (input: ["ibu", "rumah", "pulang"], output: "Ibu sudah pulang ke rumah.")
    ]
    
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
    
    /// Merges consecutive single-letter tokens separated by space tokens into complete words.
    func preprocessTokens(_ rawTokens: [String]) -> [String] {
        var processed: [String] = []
        var currentWordLetters: [String] = []
        
        // Clean tokens from any numeric ID prefixes first and lowercase them
        let cleanedTokens = rawTokens.map { stripLabelID($0).lowercased() }
        
        for token in cleanedTokens {
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
    
    /// Construct the prompt with instructions and examples.
    /// When `caregiverMessage` is provided, injects conversation context so the FM
    /// treats tokens as a reply to the caregiver.
    func buildPrompt(for tokens: [String], caregiverMessage: String? = nil) -> String {
        let cleanTokens = preprocessTokens(tokens)
        var prompt = "\(systemPrompt)\n\n"
        
        // Inject caregiver context if present
        if let message = caregiverMessage {
            prompt += "\(caregiverContextPrompt)\n"
            prompt += "Caregiver said: \"\(message)\"\n\n"
        }
        
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
    
    /// Corrects BISINDO tokens using Apple Intelligence on-device model.
    /// Pass `caregiverMessage` when the caregiver spoke first and the Teman Tuli is replying.
    func translateOnDevice(tokens: [String], caregiverMessage: String? = nil) async throws -> String {
        let prompt = buildPrompt(for: tokens, caregiverMessage: caregiverMessage)
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
/// Pass `caregiverMessage` when the caregiver spoke first and the Teman Tuli is replying.
func checkFM(input: [String], caregiverMessage: String? = nil) async throws -> String {
    let translator = BISINDOTranslator()
    return try await translator.translateOnDevice(tokens: input, caregiverMessage: caregiverMessage)
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
