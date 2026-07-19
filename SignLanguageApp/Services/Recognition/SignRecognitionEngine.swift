//
//  SignRecognitionEngine.swift
//  SignLanguageApp
//
//  Created by rahdeva on 17/07/26.
//
//  Handles debouncing raw CoreML predictions into stable words,
//  accumulates a word sequence, and automatically builds a natural
//  sentence after a configurable silence gap using Foundation Models
//  (iOS 26+) or a local fallback.
//

import Combine
import Foundation
import SwiftUI

// MARK: - Detected Word Model
struct DetectedWord: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let timestamp: Date
}

// MARK: - SignRecognitionEngine
@MainActor
final class SignRecognitionEngine: ObservableObject {

    // MARK: - Published State
    @Published var wordSequence: [DetectedWord] = []
    @Published var builtSentence: String = ""
    @Published var isBuildingSentence: Bool = false
    @Published var sentenceError: String? = nil
    /// Countdown to auto-build, 0.0 when idle (not waiting)
    @Published var silenceProgress: Double = 0.0

    // MARK: - Configuration
    /// Consecutive inference windows that must agree before accepting a word.
    let stableThreshold: Int
    /// Inference windows before the same word can be re-accepted.
    let cooldownThreshold: Int
    /// Maximum words before auto-building immediately.
    let maxWords: Int
    /// Seconds of silence after the last accepted word before auto-building.
    let silenceDelay: TimeInterval
    /// Minimum accepted words required before generating a sentence.
    private let minimumWordsForSentence = 2

    // MARK: - Private Debounce State (MainActor)
    private var pendingWord: String = ""
    private var pendingCount: Int = 0
    private var lastAcceptedWord: String = ""
    private var cooldownCounter: Int = 0

    // MARK: - Silence Timer
    private var silenceTimer: Timer?
    private var silenceStart: Date?
    private var silenceDisplayLink: CADisplayLink?

    init(
        stableThreshold:   Int          = 2,
        cooldownThreshold: Int          = 5,
        maxWords:          Int          = 12,
        silenceDelay:      TimeInterval = 2.5
    ) {
        self.stableThreshold   = stableThreshold
        self.cooldownThreshold = cooldownThreshold
        self.maxWords          = maxWords
        self.silenceDelay      = silenceDelay
    }

    // MARK: - Feed Inference Result
    /// Call this on every inference result (4x/sec from CameraManager).
    func feed(rawLabel: String, confidence: Double) {
        guard confidence >= 0.50 else {
            cooldownCounter = max(0, cooldownCounter - 1)
            return
        }

        let word = Self.cleanLabel(rawLabel)

        if word == pendingWord {
            pendingCount += 1
        } else {
            pendingWord = word
            pendingCount = 1
        }

        if cooldownCounter > 0 { cooldownCounter -= 1 }

        guard pendingCount == stableThreshold else { return }

        let isRepeat = (word == lastAcceptedWord)
        let cooldownPassed = cooldownCounter == 0

        if !isRepeat || cooldownPassed {
            acceptWord(word)
        }
    }

    // MARK: - Manual Controls
    func removeLastWord() {
        guard !wordSequence.isEmpty else { return }
        wordSequence.removeLast()
        builtSentence = ""
        if wordSequence.isEmpty {
            cancelSilenceTimer()
        } else {
            restartSilenceTimer()
        }
    }

    func removeWord(id: DetectedWord.ID) {
        guard let index = wordSequence.firstIndex(where: { $0.id == id }) else { return }
        wordSequence.remove(at: index)
        builtSentence = ""
        if wordSequence.isEmpty {
            cancelSilenceTimer()
        } else {
            restartSilenceTimer()
        }
    }

    func clearAll() {
        cancelSilenceTimer()
        wordSequence = []
        builtSentence = ""
        sentenceError = nil
        silenceProgress = 0
        pendingWord = ""
        pendingCount = 0
        lastAcceptedWord = ""
        cooldownCounter = 0
    }

    // MARK: - Sentence Building (called automatically or manually)
    func buildSentence() {
        guard wordSequence.count >= minimumWordsForSentence, !isBuildingSentence else { return }
        cancelSilenceTimer()
        let words = wordSequence.map(\.text)

        Task {
            isBuildingSentence = true
            sentenceError = nil
            let result = await buildWithFoundationModels(words: words)
            builtSentence = result
            isBuildingSentence = false
        }
    }

    // MARK: - Private Helpers

    private func acceptWord(_ word: String) {
        lastAcceptedWord = word
        cooldownCounter = cooldownThreshold
        pendingCount = 0
        builtSentence = ""

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            wordSequence.append(DetectedWord(text: word, timestamp: Date()))
        }

        if wordSequence.count >= maxWords {
            buildSentence()
        } else {
            restartSilenceTimer()
        }
    }

    // MARK: - Silence Timer Logic

    private func restartSilenceTimer() {
        cancelSilenceTimer()
        guard !wordSequence.isEmpty else { return }

        silenceStart = Date()
        silenceProgress = 0.0

        // Progress updater — fires ~60fps so the arc animates smoothly
        let dl = CADisplayLink(target: SilenceTickProxy(engine: self), selector: #selector(SilenceTickProxy.tick))
        dl.add(to: .main, forMode: .common)
        silenceDisplayLink = dl

        // Actual build trigger
        let delay = silenceDelay
        silenceTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.cancelDisplayLink()
                self.silenceProgress = 0
                self.buildSentence()
            }
        }
    }

    private func cancelSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        cancelDisplayLink()
        silenceStart = nil
        silenceProgress = 0
    }

    private func cancelDisplayLink() {
        silenceDisplayLink?.invalidate()
        silenceDisplayLink = nil
    }

    fileprivate func tickSilenceProgress() {
        guard let start = silenceStart else { return }
        let elapsed = Date().timeIntervalSince(start)
        silenceProgress = min(elapsed / silenceDelay, 1.0)
    }

    // MARK: - Label Cleaning
    static func cleanLabel(_ raw: String) -> String {
        let parts = raw.split(separator: "_", maxSplits: 1)
        if parts.count == 2, Int(parts[0]) != nil {
            return String(parts[1]).capitalized
        }
        return raw.capitalized
    }

    // MARK: - Foundation Models
    private func buildWithFoundationModels(words: [String]) async -> String {
        if #available(iOS 26.0, macOS 26.0, *) {
            return await buildWithAI(words: words)
        }
        return fallbackSentence(words: words)
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func buildWithAI(words: [String]) async -> String {
        if let sentence = try? await checkFM(input: words), !sentence.isEmpty {
            return sentence
        }

        sentenceError = "Apple Intelligence is unavailable. Showing raw detected words."
        return fallbackSentence(words: words)
    }

    private func fallbackSentence(words: [String]) -> String {
        words.joined(separator: " ")
    }
}

// MARK: - CADisplayLink Proxy (avoids retain cycle)
// CADisplayLink holds a strong reference to its target, so we use a weak-ref proxy.
private final class SilenceTickProxy: NSObject {
    weak var engine: SignRecognitionEngine?
    init(engine: SignRecognitionEngine) { self.engine = engine }

    @objc func tick() {
        Task { @MainActor [weak self] in
            self?.engine?.tickSilenceProgress()
        }
    }
}
