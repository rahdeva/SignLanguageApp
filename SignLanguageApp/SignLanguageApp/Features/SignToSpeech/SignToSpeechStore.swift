import CoreImage
import Observation

import CoreImage
import Observation

@MainActor
@Observable
final class SignToSpeechStore {
    private let appStore: AppStore
    private var predictionTask: Task<Void, Never>?

    var predictedText: String = ""
    var isCapturing = false
    var isAuthorized = false

    init(appStore: AppStore) {
        self.appStore = appStore
    }

    func startCapture() {
        guard !isCapturing else { return }
        Task { [self] in
            do {
                isAuthorized = await PermissionService.requestCamera()
                guard isAuthorized else {
                    appStore.error = .permissionDenied("camera")
                    appStore.showingError = true
                    return
                }
                isCapturing = true
                appStore.isPredicting = true
                try await appStore.cameraService.start()

                predictionTask = Task { [weak self] in
                    for await pixelBuffer in appStore.cameraService.pixelBufferStream {
                        try? await Task.sleep(for: .milliseconds(500))
                        self?.predictedText = "Sign detected..."
                        appStore.signPredictionOutput = "Sign detected..."
                    }
                }
            } catch {
                appStore.error = .cameraUnavailable
                appStore.showingError = true
                isCapturing = false
                appStore.isPredicting = false
            }
        }
    }

    func speakPrediction() {
        let text = predictedText
        guard !text.isEmpty else { return }
        Task {
            await appStore.synthesizerService.speak(text)
            appStore.addToHistory(message: text, role: .assistantSpoke)
        }
    }

    func stopCapture() {
        isCapturing = false
        appStore.isPredicting = false
        predictionTask?.cancel()
        predictionTask = nil
        Task { await appStore.cameraService.stop() }
    }
}
