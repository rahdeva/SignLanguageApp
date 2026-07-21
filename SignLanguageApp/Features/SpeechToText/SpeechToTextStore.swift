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
    var refinedText: String = ""
    var isRecording = false
    var isRefining = false
    var isAuthorized = false

    init(appStore: AppStore) {
        self.appStore = appStore
    }

    /// Request mic permission and start streaming transcription.
    func startRecording() {
        guard !isRecording else { return }
        refinedText = ""
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

                for try await text in await appStore.speechService.start(locale: Locale(identifier: "id-ID")) {
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

        // AI-refine the caregiver's speech with conversation context
        Task {
            isRefining = true
            let context = ConversationContextService.buildContextString(
                from: appStore.conversationHistory,
                currentSpeaker: .userSpoke
            )
            do {
                let refined = try await refineCaregiverSpeech(
                    rawSpeech: finalText,
                    conversationContext: context,
                    targetLanguage: appStore.languageSettings.ttsLanguage
                )
                if !refined.isEmpty {
                    refinedText = refined
                    // Write the refined text back to history replacing the raw one
                    if let lastIndex = appStore.conversationHistory.lastIndex(where: { $0.role == .userSpoke }) {
                        appStore.conversationHistory[lastIndex] = Conversation(message: refined, role: .userSpoke)
                    }
                } else {
                    refinedText = finalText
                }
            } catch {
                print("❌ CaregiverSpeechRefiner Error: \(error)")
                refinedText = finalText
            }
            isRefining = false
        }
    }
}
