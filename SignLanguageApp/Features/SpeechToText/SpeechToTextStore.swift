//
//  SpeechToTextStore.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import Foundation
import Observation

/// State and actions for the Speech→Text pipeline.
@MainActor
@Observable
final class SpeechToTextStore {
    private let appStore: AppStore

    var transcribedText: String = ""
    var isRecording = false
    var isAuthorized = false

    init(appStore: AppStore) {
        self.appStore = appStore
    }

    /// Request mic permission and start streaming transcription.
    func startRecording() {
        guard !isRecording else { return }
        Task { [appStore] in
            do {
                isAuthorized = await PermissionService.requestMicrophone()
                guard isAuthorized else {
                    appStore.error = .permissionDenied("microphone")
                    appStore.showingError = true
                    return
                }
                _ = await PermissionService.requestSpeech()
                isRecording = true
                appStore.isTranscribing = true

                let locale = appStore.languageSettings.speechLanguage.locale
                for try await text in await appStore.speechService.start(locale: locale) {
                    transcribedText = text
                    appStore.speechToTextOutput = text
                }
            } catch {
                let msg = error.localizedDescription
                if !msg.localizedCaseInsensitiveContains("cancel") &&
                   !msg.localizedCaseInsensitiveContains("cancelled") {
                    appStore.error = .unknown(msg)
                    appStore.showingError = true
                }
                isRecording = false
                appStore.isTranscribing = false
            }
        }
    }

    /// Stop recording and save the final text to conversation history.
    func stopRecording() {
        isRecording = false
        appStore.isTranscribing = false
        Task { await appStore.speechService.stop() }
        let finalText = transcribedText
        transcribedText = ""
        guard !finalText.isEmpty else { return }
        appStore.addToHistory(message: finalText, role: .userSpoke)
    }
}
