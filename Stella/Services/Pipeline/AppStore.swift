//
//  AppStore.swift
//  Stella
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import Observation

/// Central state coordinator. Owns all services and exposes reactive state to the view layer.
@MainActor
@Observable
final class AppStore {
    // MARK: - Services
    private(set) var cameraService: CameraService
    private(set) var speechService: SpeechRecognizerService
    private(set) var synthesizerService: SpeechSynthesizerService
    private(set) var inferencer: SignLanguageInferencing

    // MARK: - Language
    var languageSettings: LanguageSettings = LanguageSettings()

    // MARK: - Speech-to-Text
    var speechToTextOutput: String = ""
    var isTranscribing = false
    var isMicAuthorized = false

    // MARK: - Sign-to-Speech
    var signPredictionOutput: String = ""
    var isPredicting = false
    var isCameraAuthorized = false

    // MARK: - Error
    var error: AppError?
    var showingError = false

    // MARK: - Init
    init(inferencer: SignLanguageInferencing = SignLanguageInferencer()) {
        self.inferencer = inferencer
        cameraService = CameraService()
        speechService = SpeechRecognizerService()
        synthesizerService = SpeechSynthesizerService()
    }

    // MARK: - Actions

    /// Check all permissions at launch. Individual services re-check on demand.
    func checkPermissions() async {
        isCameraAuthorized = await PermissionService.requestCamera()
        isMicAuthorized = await PermissionService.requestMicrophone()
        if isMicAuthorized {
            _ = await PermissionService.requestSpeech()
        }
    }

    func dismissError() {
        error = nil
        showingError = false
    }

    /// Speak text aloud using the current TTS language setting.
    func speak(_ text: String) async {
        await synthesizerService.speak(text, language: languageSettings.ttsLanguage)
    }

    /// Stop speaking immediately.
    func stopSpeaking() {
        Task { await synthesizerService.stop() }
    }
}
