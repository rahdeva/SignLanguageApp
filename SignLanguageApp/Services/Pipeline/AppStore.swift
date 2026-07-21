//
//  AppStore.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import Foundation
import Observation
import SwiftData

/// Central state coordinator. Owns all services and exposes reactive state to the view layer.
@MainActor
@Observable
final class AppStore {
    // MARK: - Services
    private(set) var cameraService: CameraService
    private(set) var speechService: SpeechRecognizerService
    private(set) var synthesizerService: SpeechSynthesizerService
    private(set) var inferencer: SignLanguageInferencing
    private(set) var sessionService: SessionService

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

    // MARK: - Session
    /// Active session ID — nil when no session is active.
    var activeSessionId: UUID?

    /// The currently active session, if any.
    var activeSession: ChatSession? {
        guard let id = activeSessionId else { return nil }
        return sessionService.allSessions().first { $0.id == id && $0.isActive }
    }

    /// All sessions from persistent storage.
    var allSessions: [ChatSession] { sessionService.allSessions() }

    // MARK: - Error
    var error: AppError?
    var showingError = false

    // MARK: - Init
    init(
        container: ModelContainer = try! ModelContainer(for: ChatSession.self, ChatMessage.self),
        inferencer: SignLanguageInferencing = SignLanguageInferencer()
    ) {
        self.inferencer = inferencer
        self.sessionService = SessionService(container: container)
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

    /// Start a new session.
    func startSession(title: String? = nil) {
        let session = sessionService.createSession(title: title)
        activeSessionId = session.id
    }

    /// End the current active session.
    func endSession() {
        guard let session = activeSession else { return }
        sessionService.endSession(session)
        activeSessionId = nil
    }

    /// Add a message to the active session. If no active session exists, creates one.
    func addToHistory(message: String, role: MessageRole) {
        let session: ChatSession
        if let existing = activeSession {
            session = existing
        } else {
            session = sessionService.createSession()
            activeSessionId = session.id
        }
        sessionService.appendMessage(to: session, content: message, role: role)
    }

    /// Resume a past session — sets it as the active session.
    func resumeSession(_ session: ChatSession) {
        session.endedAt = nil
        activeSessionId = session.id
        sessionService.save()
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
