//
//  TwoWayConversationStore.swift
//  StellaApp
//
//  Created by rahdeva on 19/07/26.
//  Integrated two-way conversation mode controlled by eye tracking (EAR).
//

import Combine
import Foundation
import QuartzCore
import SwiftUI

// MARK: - Conversation Mode State
enum ConversationModeState: Equatable {
    /// Microphone active (`SpeechToTextStore`), listening to partner speech.
    case speechToTextActive
    /// Eye wink detected, counting down `1.0` second before switching to sign mode.
    case winkingTrigger(progress: Double)
    /// Camera active, recording signs (`SignRecognitionEngine`) until both eyes open.
    case signLanguageActive
    /// Both eyes open triggered, reading aloud the detected sign sentence via `TTS`.
    case speakingTTS
}

// MARK: - TwoWayConversationStore
@MainActor
final class TwoWayConversationStore: ObservableObject {

    // MARK: - Published State
    @Published var state: ConversationModeState = .speechToTextActive
    @Published var winkProgress: Double = 0.0
    @Published var lastTTSMessage: String = ""
    @Published var isEyeControlledEnabled: Bool = true
    /// Toggle to enable/disable AI sentence refinement right before TTS speaking
    @Published var isAIRefinementEnabled: Bool = true {
        didSet { recognizer.isAIRefinementEnabled = isAIRefinementEnabled }
    }
    /// Whether sign language detection mode is currently active (winking or actively signing)
    var isSignDetectionActiveForOverlay: Bool {
        switch state {
        case .signLanguageActive, .winkingTrigger:
            return true
        case .speechToTextActive, .speakingTTS:
            return false
        }
    }

    // MARK: - Dependencies
    let cameraManager: CameraManager
    let recognizer: SignRecognitionEngine
    private(set) var speechStore: SpeechToTextStore?
    private(set) var appStore: AppStore?

    // MARK: - Private State
    private var cancellables = Set<AnyCancellable>()
    private var winkStart: Date?
    private var winkDisplayLink: CADisplayLink?
    private var bothEyesOpenTimer: Timer?

    init(
        cameraManager: CameraManager,
        recognizer: SignRecognitionEngine
    ) {
        self.cameraManager = cameraManager
        self.recognizer = recognizer
    }

    // MARK: - Lifecycle Controls
    func start(appStore: AppStore, speechStore: SpeechToTextStore) {
        self.appStore = appStore
        self.speechStore = speechStore
        stop() // Clean up any existing subscriptions
        if !cameraManager.isRunning {
            cameraManager.checkPermissions()
        }
        speechStore.startRecording()
        state = .speechToTextActive
        winkProgress = 0.0

        setupObservers()
    }

    func stop() {
        cancelWinkTimer()
        bothEyesOpenTimer?.invalidate()
        bothEyesOpenTimer = nil
        cancellables.removeAll()

        speechStore?.stopRecording()
        appStore?.stopSpeaking()
        state = .speechToTextActive
        winkProgress = 0.0
    }

    // MARK: - Observers Setup
    private func setupObservers() {
        // Observe eye states
        Publishers.CombineLatest3(
            cameraManager.$isLeftEyeClosed,
            cameraManager.$isRightEyeClosed,
            cameraManager.$isFaceDetected
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] leftClosed, rightClosed, faceDetected in
            self?.handleEyeTrackingUpdate(
                isLeftClosed: leftClosed,
                isRightClosed: rightClosed,
                isFaceDetected: faceDetected
            )
        }
        .store(in: &cancellables)

        // Observe sign detection during signLanguageActive mode
        cameraManager.$currentSign
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sign in
                self?.handleNewSign(sign)
            }
            .store(in: &cancellables)
    }

    // MARK: - Eye Tracking & State Transitions
    private func handleEyeTrackingUpdate(
        isLeftClosed: Bool,
        isRightClosed: Bool,
        isFaceDetected: Bool
    ) {
        guard isEyeControlledEnabled, isFaceDetected else { return }

        // Either eye closed or winking
        let eitherClosed = isLeftClosed || isRightClosed
        let bothOpen = !isLeftClosed && !isRightClosed

        switch state {
        case .speechToTextActive, .winkingTrigger:
            if eitherClosed && !bothOpen {
                if case .speechToTextActive = state {
                    startWinkTimer()
                }
            } else if bothOpen {
                if case .winkingTrigger = state {
                    cancelWinkTimer()
                    state = .speechToTextActive
                    winkProgress = 0.0
                }
            }

        case .signLanguageActive:
            // Check for return condition: both eyes open (`kedua mata terbuka`)
            if bothOpen {
                if bothEyesOpenTimer == nil {
                    // Debounce both eyes open for 0.4s to prevent accidental exit during a quick blink
                    bothEyesOpenTimer = Timer.scheduledTimer(
                        withTimeInterval: 0.4,
                        repeats: false
                    ) { [weak self] _ in
                        Task { @MainActor [weak self] in
                            self?.transitionToTTSAndSpeak()
                        }
                    }
                }
            } else {
                bothEyesOpenTimer?.invalidate()
                bothEyesOpenTimer = nil
            }

        case .speakingTTS:
            // Ignore eye blinks while TTS is speaking
            break
        }
    }

    // MARK: - Wink Timer Logic
    private func startWinkTimer() {
        winkStart = Date()
        state = .winkingTrigger(progress: 0.0)
        winkProgress = 0.0

        let dl = CADisplayLink(
            target: ConversationTickProxy(store: self),
            selector: #selector(ConversationTickProxy.tick)
        )
        dl.add(to: .main, forMode: .common)
        winkDisplayLink = dl
    }

    private func cancelWinkTimer() {
        winkDisplayLink?.invalidate()
        winkDisplayLink = nil
        winkStart = nil
        winkProgress = 0.0
    }

    fileprivate func tickWink() {
        guard let start = winkStart, case .winkingTrigger = state else {
            cancelWinkTimer()
            return
        }
        let elapsed = Date().timeIntervalSince(start)
        let prog = min(elapsed / 1.0, 1.0)
        winkProgress = prog
        state = .winkingTrigger(progress: prog)

        if prog >= 1.0 {
            cancelWinkTimer()
            transitionToSignLanguage()
        }
    }

    // MARK: - Mode Switch Helpers
    private func transitionToSignLanguage() {
        winkProgress = 0.0
        bothEyesOpenTimer?.invalidate()
        bothEyesOpenTimer = nil

        // Stop microphone so it doesn't record ambient noise while signing
        speechStore?.stopRecording()

        // Clear previous sign sequence
        recognizer.clearAll()

        state = .signLanguageActive
    }

    private func handleNewSign(_ sign: String) {
        guard case .signLanguageActive = state else { return }
        guard sign != "Detecting...", sign != "Uncertain" else { return }

        let cleaned = SignRecognitionEngine.cleanLabel(sign)
        let ttsLang = appStore?.languageSettings.ttsLanguage ?? .indonesian
        let translated = SignLabelTranslator.translate(
            cleaned,
            to: ttsLang
        )
        recognizer.feed(
            rawLabel: translated,
            confidence: cameraManager.currentConfidence
        )
    }

    private func transitionToTTSAndSpeak() {
        bothEyesOpenTimer?.invalidate()
        bothEyesOpenTimer = nil

        guard case .signLanguageActive = state else { return }
        state = .speakingTTS

        Task {
            // Prepare sentence to speak
            var textToSpeak = recognizer.builtSentence
            if isAIRefinementEnabled && !recognizer.wordSequence.isEmpty {
                // When signer opens both eyes, run FoundationModels to refine raw tokens into a natural sentence before TTS
                if textToSpeak.isEmpty || recognizer.isBuildingSentence {
                    textToSpeak = await recognizer.buildSentenceAsync()
                }
            } else if !recognizer.wordSequence.isEmpty {
                // If AI refinement is disabled, join raw words directly if builtSentence is empty
                if textToSpeak.isEmpty {
                    textToSpeak = recognizer.wordSequence.map(\.text).joined(separator: " ")
                }
            }

            guard !textToSpeak.isEmpty else {
                // Nothing signed, smoothly return to speech-to-text
                self.state = .speechToTextActive
                self.speechStore?.startRecording()
                return
            }

            self.lastTTSMessage = textToSpeak

            // Speak text aloud and suspend until speech finished (`didFinish`)
            if let appStore = self.appStore {
                appStore.addToHistory(message: textToSpeak, role: .userSigned)
                await appStore.speak(textToSpeak)
            }

            // Automatically transition back to speech-to-text mode
            if self.state == .speakingTTS {
                self.state = .speechToTextActive
                self.speechStore?.startRecording()
            }
        }
    }

    // MARK: - Manual Override Controls
    func manualSwitchToSign() {
        guard state != .signLanguageActive else { return }
        cancelWinkTimer()
        transitionToSignLanguage()
    }

    func manualSwitchToSpeech() {
        cancelWinkTimer()
        bothEyesOpenTimer?.invalidate()
        bothEyesOpenTimer = nil
        recognizer.clearAll()
        state = .speechToTextActive
        speechStore?.startRecording()
    }
}

// MARK: - CADisplayLink Proxy
private final class ConversationTickProxy: NSObject {
    weak var store: TwoWayConversationStore?
    init(store: TwoWayConversationStore) { self.store = store }

    @objc func tick() {
        Task { @MainActor [weak self] in
            self?.store?.tickWink()
        }
    }
}
