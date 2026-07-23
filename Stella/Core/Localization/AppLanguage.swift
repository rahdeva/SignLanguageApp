//
//  AppLanguage.swift
//  Stella
//
//  Created by Antigravity on 19/07/26.
//

import AVFAudio
import Observation
import Speech

// MARK: - AppLanguage

/// The two supported app languages.
/// Marked `nonisolated` so value-type helpers like `voice` and `locale` can be
/// read from any isolation domain (e.g. the speech synthesizer/recognizer actors).
nonisolated enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case indonesian = "id"
    case english    = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .indonesian: "Bahasa Indonesia"
        case .english:    "English"
        }
    }

    /// BCP-47 locale tag used by AVSpeechSynthesisVoice and SFSpeechRecognizer.
    var bcp47: String {
        switch self {
        case .indonesian: "id-ID"
        case .english:    "en-US"
        }
    }

    /// Locale for use with SFSpeechRecognizer.
    var locale: Locale { Locale(identifier: bcp47) }

    /// AVSpeechSynthesisVoice for this language, falling back to the other language.
    var voice: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(language: bcp47)
            ?? AVSpeechSynthesisVoice(language: AppLanguage.english.bcp47)
    }
}

// MARK: - LanguageSettings

/// Persistent store for all three independently configurable language axes.
/// Injected via SwiftUI environment so any view or store can read it.
@MainActor
@Observable
final class LanguageSettings {

    // MARK: - UserDefaults keys
    private enum Key {
        static let app    = "lang.app"
        static let tts    = "lang.tts"
        static let speech = "lang.speech"
    }

    // MARK: - Published axes

    /// Language used to render all UI strings (applied via `.environment(\.locale, ...)`).
    var appLanguage: AppLanguage {
        didSet { UserDefaults.standard.set(appLanguage.rawValue, forKey: Key.app) }
    }

    /// Voice language used by AVSpeechSynthesizer when speaking a recognised sign.
    var ttsLanguage: AppLanguage {
        didSet { UserDefaults.standard.set(ttsLanguage.rawValue, forKey: Key.tts) }
    }

    /// Locale passed to SFSpeechRecognizer for the Speech→Text pipeline.
    var speechLanguage: AppLanguage {
        didSet { UserDefaults.standard.set(speechLanguage.rawValue, forKey: Key.speech) }
    }

    // MARK: - Init

    init() {
        func load(_ key: String) -> AppLanguage {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let lang = AppLanguage(rawValue: raw)
            else { return .indonesian }
            return lang
        }
        appLanguage    = load(Key.app)
        ttsLanguage    = load(Key.tts)
        speechLanguage = load(Key.speech)
    }
}

// MARK: - Dynamic String Localization Helper

extension String {
    /// Lookup this key in the `Localizable.strings` table corresponding to the given `AppLanguage`.
    func localized(for language: AppLanguage) -> String {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(self, tableName: "Localizable", comment: "")
        }
        return bundle.localizedString(forKey: self, value: nil, table: "Localizable")
    }
}
