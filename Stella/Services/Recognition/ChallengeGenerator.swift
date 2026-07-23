//
//  ChallengeGenerator.swift
//  Stella
//
//  Created by Antigravity on 22/07/26.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct PracticeChallenge: Equatable {
    let question: String
    let targetTokens: [String]
}

struct ChallengeGenerator {
    static let availableWords = [
        "Saya", "Lagi", "Makan", "Dengar", "Motor", "Belajar", "Cari", "Hari",
        "Ingat", "Maaf", "Terima kasih", "Tuli", "Apa", "Siapa", "Kapan", "Di mana",
        "Mengapa", "Bagaimana", "Merah", "Kuning", "Hijau", "Hitam", "Berangkat",
        "Datang", "Teman", "Keluarga", "Rumah", "Pagi", "Siang", "Sore", "Malam", "Air"
    ]
    
    static let fallbacks = [
        PracticeChallenge(question: "Kamu sedang apa?", targetTokens: ["Saya", "Lagi", "Makan"]),
        PracticeChallenge(question: "Kamu mau pergi ke mana?", targetTokens: ["Saya", "Rumah", "Teman"]),
        PracticeChallenge(question: "Bagaimana kamu berangkat?", targetTokens: ["Saya", "Motor"]),
        PracticeChallenge(question: "Kapan kamu datang?", targetTokens: ["Saya", "Datang", "Malam"]),
        PracticeChallenge(question: "Siapa itu?", targetTokens: ["Teman", "Saya"]),
        PracticeChallenge(question: "Di mana rumah kamu?", targetTokens: ["Rumah", "Saya"]),
        PracticeChallenge(question: "Mengapa kamu belajar?", targetTokens: ["Saya", "Ingat", "Keluarga"]),
        PracticeChallenge(question: "Kapan kamu mau makan?", targetTokens: ["Saya", "Makan", "Siang"]),
        PracticeChallenge(question: "Warna apa motor kamu?", targetTokens: ["Motor", "Saya", "Merah"]),
        PracticeChallenge(question: "Apa kamu dengar air?", targetTokens: ["Saya", "Dengar", "Air"])
    ]
    
    /// Generates a challenge dynamically using Foundation Models, falling back to a preset if unavailable or failing.
    static func generateChallenge(targetLanguage: AppLanguage = .indonesian) async -> PracticeChallenge {
        #if canImport(FoundationModels)
        do {
            let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
            guard model.isAvailable else {
                return fallbacks.randomElement()!
            }
            
            // Pass a simple English system instruction to bypass language pre-flight validation checks on iOS
            let simpleInstructions = "You are a sign language practice generator assistant."
            let session = LanguageModelSession(model: model, instructions: simpleInstructions)
            
            let wordList = availableWords.joined(separator: ", ")
            let prompt = """
            # Role
            You are a practice-item generator for a caregiver–sign-language communication app. 
            You create short caregiver questions paired with a plausible sign-token answer, 
            built strictly from a closed vocabulary, so learners can practice producing 
            correct sign-token sequences.

            # Task
            Generate a single random Caregiver question in \(targetLanguage == .english ? "English" : "Indonesian"), 
            plus a matching target sign-token sequence answer.

            # Question Freedom
            The caregiver question is FREE-FORM natural conversational language. It does NOT need to restrict its words to the vocabulary list. Write it as a completely natural, normal question sentence (e.g. "Kamu mau pergi ke mana?", "Apakah kamu mau makan siang?"). It MUST NOT contain any commas separating random words, lists of words, brackets, or vocabulary tokens. It must be written exactly as a normal spoken question sentence.

            # Vocabulary
            The token sequence must be built ONLY from this list (case-insensitive matching, 
            but output each token using its exact casing as it appears here): \(wordList)

            Multi-word entries in the list (e.g. "Terima kasih") are single atomic tokens — 
            never split them into separate tokens or reorder their internal words.

            # Rules

            1. Token count: the token sequence must contain exactly 2 to 4 tokens.

            2. Closed vocabulary, no invention: do not invent, translate, or substitute any 
               word not in wordList. Tokens are bare vocabulary items — do not inflect them, 
               add prefixes/suffixes, or add function words (copulas, prepositions, 
               conjunctions) that aren't themselves entries in wordList. If no grammatically 
               sensible answer is possible using only list words, choose a different question 
               that IS answerable within the list.

            3. No invented causes, negation, or missing concepts: the answer may not rely on 
               causal logic ("because"), negation ("not"/"haven't"), or any other concept 
               unless a token for it explicitly exists in wordList. Don't pick a question 
               whose natural answer needs a concept the vocabulary can't express.

            4. Verb availability: not every combination of available words will include a 
               verb, and that's fine. If wordList's verbs can't sensibly answer a given 
               question, prefer a question whose natural answer is a no-verb structure 
               instead (e.g. a possessive or locative phrase like "Saya, Rumah" for "whose 
               house is this?") rather than forcing in an invented verb.

            5. Pronoun use: if wordList contains a first-person pronoun (or any pronoun), 
               use it explicitly in self-referential answers rather than omitting it — the 
               token sequence is the practice target, so a dropped subject defeats the 
               exercise. Never invent a pronoun that isn't in wordList.

            6. Aspect markers: if wordList contains an ongoing-action/aspect gloss (e.g. a 
               word like "Lagi" meaning "sedang"), treat it as carrying one fixed, 
               consistent meaning throughout, and include at most one aspect marker per 
               answer.

            7. Descriptive word placement: if the answer includes a descriptive/color-type 
               token, place it immediately after the noun it modifies, so the sequence 
               reads unambiguously as "noun + its descriptor" rather than sitting detached 
               from what it modifies.

            8. Plural/emphasis: if the natural answer needs to convey plurality or emphasis 
               and no dedicated plural token exists in wordList, use reduplication 
               (repeating the token) rather than inventing a quantifier word not in the 
               list.

            9. Grammatical coherence: the target tokens MUST represent a direct, logical, 
               and correct answer to the question (e.g. if the question is "Kamu mau pergi 
               ke mana?", the target tokens must be a direct answer like "Saya", "Rumah", 
               "Teman" meaning "I'm going to a friend's house"). It must make perfect 
               sense as an answer.

            10. Question style: the question must be short and natural, phrased the way a 
                real caregiver would ask it (needs, feelings, daily activities, health, 
                routine, location, or time). Vary the topic and structure between 
                generations — avoid defaulting to the same question pattern each time 
                (e.g. don't always ask "Kamu sedang apa?" / "What are you doing?").

            11. Question formatting: The question MUST be a simple, natural question sentence 
                (e.g. "Kamu mau pergi ke mana?"). It MUST NOT contain any commas separating 
                list words, target tokens, or bracketed vocabulary words. It must look 
                exactly like normal speech without comma-separated list artifacts.

            # Output Format
            Output ONLY these two lines, exactly, with no extra text, explanations, labels, 
            or translations before or after:
            Question: <question>
            Tokens: <comma-separated tokens>

            Example (for format only — generate a different question and answer):
            Question: Kamu sedang apa?
            Tokens: Saya, Lagi, Makan

            Now generate one new, randomly distinct challenge.
            """
            
            let response = try await session.respond(to: prompt)
            let rawContent = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let parsed = parse(rawContent) {
                return parsed
            }
        } catch {
            print("⚠️ FoundationModels challenge generation failed: \(error)")
        }
        #endif
        
        return fallbacks.randomElement()!
    }
    
    /// Generates a matching target token sequence for a custom caregiver question spoken by the user.
    static func generateTokens(for question: String, targetLanguage: AppLanguage = .indonesian) async -> [String] {
        #if canImport(FoundationModels)
        do {
            let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
            guard model.isAvailable else {
                return getFallbackTokens(for: question)
            }
            
            let simpleInstructions = "You are a sign language translation sequence helper."
            let session = LanguageModelSession(model: model, instructions: simpleInstructions)
            
            let wordList = availableWords.joined(separator: ", ")
            let prompt = """
            Task: Given this Caregiver question: "\(question)"
            Generate a matching target sign token sequence that represents a direct, logical, and correct answer to the question using ONLY words from this vocabulary (case-insensitive): \(wordList)
            
            Rules:
            1. The target sequence MUST consist of exactly 2 to 4 words from the vocabulary list.
            2. It must represent a grammatically correct, direct answer to the question.
            3. Output format MUST be exactly:
               Tokens: <comma-separated tokens>
            
            Now output the tokens:
            """
            
            let response = try await session.respond(to: prompt)
            let rawContent = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let tokensLine = rawContent.components(separatedBy: .newlines).first(where: { $0.lowercased().hasPrefix("tokens:") }) {
                let parts = tokensLine.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let tokensStr = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let parsedTokens = tokensStr.components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"“'[]()\n\r")) }
                        .filter { !$0.isEmpty }
                    
                    let vocabSet = Set(availableWords.map { $0.lowercased() })
                    let validTokens = parsedTokens.compactMap { token -> String? in
                        let cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines)
                        if vocabSet.contains(cleaned.lowercased()) {
                            return availableWords.first(where: { $0.lowercased() == cleaned.lowercased() })
                        }
                        return nil
                    }
                    if validTokens.count >= 2 {
                        return validTokens
                    }
                }
            }
        } catch {
            print("⚠️ FoundationModels custom tokens generation failed: \(error)")
        }
        #endif
        
        return getFallbackTokens(for: question)
    }
    
    private static func getFallbackTokens(for question: String) -> [String] {
        let q = question.lowercased()
        if q.contains("apa") || q.contains("what") {
            return ["Saya", "Lagi", "Makan"]
        } else if q.contains("mana") || q.contains("where") {
            return ["Saya", "Rumah", "Teman"]
        } else if q.contains("siapa") || q.contains("who") {
            return ["Teman", "Saya"]
        } else if q.contains("kapan") || q.contains("when") {
            return ["Saya", "Datang", "Malam"]
        }
        return ["Saya", "Lagi", "Belajar"]
    }
    
    private static func parse(_ text: String) -> PracticeChallenge? {
        let lines = text.components(separatedBy: .newlines)
        var question: String? = nil
        var tokens: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().hasPrefix("question:") {
                let parts = trimmed.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    question = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"“'\n\r"))
                }
            } else if trimmed.lowercased().hasPrefix("tokens:") {
                let parts = trimmed.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let tokensStr = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let parsedTokens = tokensStr.components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"“'[]()\n\r")) }
                        .filter { !$0.isEmpty }
                    
                    let vocabSet = Set(availableWords.map { $0.lowercased() })
                    let validTokens = parsedTokens.compactMap { token -> String? in
                        let cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines)
                        if vocabSet.contains(cleaned.lowercased()) {
                            return availableWords.first(where: { $0.lowercased() == cleaned.lowercased() })
                        }
                        return nil
                    }
                    if validTokens.count >= 2 {
                        tokens = validTokens
                    }
                }
            }
        }
        
        if let q = question, !tokens.isEmpty {
            return PracticeChallenge(question: q, targetTokens: tokens)
        }
        return nil
    }
}
