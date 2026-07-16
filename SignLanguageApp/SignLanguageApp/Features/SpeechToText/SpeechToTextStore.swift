import Foundation
import Observation

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

    func startRecording() {
        guard !isRecording else { return }
        Task {
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

                for try await text in try await appStore.speechService.start() {
                    transcribedText = text
                    appStore.speechToTextOutput = text
                }
            } catch {
                appStore.error = .unknown(error.localizedDescription)
                appStore.showingError = true
                isRecording = false
                appStore.isTranscribing = false
            }
        }
    }

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
