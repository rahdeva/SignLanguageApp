//
//  SignLabelTranslator.swift
//  SignLanguageApp
//
//  Created by Antigravity on 19/07/26.
//
//  Translates BISINDO model output labels to the target language.
//  Dictionary is derived directly from the official training dataset (32 classes).
//  All translations are static and offline — no network required.
//

import Foundation

/// Translates cleaned BISINDO sign labels into the target language.
///
/// `SignRecognitionEngine.cleanLabel` strips the numeric prefix from raw model output
/// (e.g. `"10_Terima kasih"` → `"Terima Kasih"`) and capitalises each word.
/// This translator maps those cleaned Indonesian words to English when the
/// TTS/display language is set to `.english`.
enum SignLabelTranslator {

    // MARK: - Official dataset: Label → (Gloss, English)
    // Source: 32-class BISINDO Hand Action dataset used to train MyHandActionBisindoClassifier_1

    /// Maps the cleaned (capitalised) Indonesian gloss to its English translation.
    private static let idToEn: [String: String] = [
        // Label 0
        "Air":           "Water",
        // Label 1
        "Belajar":       "Learn",
        // Label 2
        "Cari":          "Search",
        // Label 3
        "Hari":          "Day",
        // Label 4
        "Ingat":         "Remember",
        // Label 5
        "Lagi":          "Again",
        // Label 6
        "Maaf":          "Sorry",
        // Label 7
        "Makan":         "Eat",
        // Label 8
        "Motor":         "Motorcycle",
        // Label 9
        "Saya":          "I",
        // Label 10  — cleanLabel capitalises each word: "Terima kasih" → "Terima Kasih"
        "Terima Kasih":  "Thank You",
        // Label 11
        "Tuli":          "Deaf",
        // Label 12
        "Apa":           "What",
        // Label 13
        "Siapa":         "Who",
        // Label 14
        "Kapan":         "When",
        // Label 15  — "Di mana" → "Di Mana"
        "Di Mana":       "Where",
        // Label 16
        "Mengapa":       "Why",
        // Label 17
        "Bagaimana":     "How",
        // Label 18
        "Merah":         "Red",
        // Label 19
        "Kuning":        "Yellow",
        // Label 20
        "Hijau":         "Green",
        // Label 21
        "Hitam":         "Black",
        // Label 22
        "Dengar":        "Hear",
        // Label 23
        "Berangkat":     "Depart",
        // Label 24
        "Datang":        "Come",
        // Label 25
        "Teman":         "Friend",
        // Label 26
        "Keluarga":      "Family",
        // Label 27
        "Rumah":         "House",
        // Label 28
        "Pagi":          "Morning",
        // Label 29
        "Siang":         "Noon",
        // Label 30
        "Sore":          "Afternoon",
        // Label 31
        "Malam":         "Night",
    ]

    // MARK: - Public API

    /// Translate a cleaned sign label into the target language.
    /// - Parameters:
    ///   - label: The cleaned gloss string produced by `SignRecognitionEngine.cleanLabel`.
    ///   - language: The desired output language.
    /// - Returns: English translation when `language == .english` and a mapping exists;
    ///   otherwise returns `label` unchanged.
    static func translate(_ label: String, to language: AppLanguage) -> String {
        guard language == .english else { return label }
        return idToEn[label] ?? label
    }
}
