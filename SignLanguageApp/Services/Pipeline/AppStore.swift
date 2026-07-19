//
//  AppStore.swift
//  SignLanguageApp
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

    // MARK: - Speech-to-Text
    var speechToTextOutput: String = ""
    var isTranscribing = false
    var isMicAuthorized = false

    // MARK: - Sign-to-Speech
    var signPredictionOutput: String = ""
    var isPredicting = false
    var isCameraAuthorized = false

    // MARK: - Conversation
    var conversationHistory: [Conversation] = []

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

    func addToHistory(message: String, role: ConversationRole) {
        conversationHistory.append(Conversation(message: message, role: role))
    }
}
