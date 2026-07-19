//
//  SignToSpeechStore.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import AVFoundation
import CoreImage
import Observation

/// State and actions for the Sign→Speech pipeline (camera + ML + TTS).
@MainActor
@Observable
final class SignToSpeechStore {
    private let appStore: AppStore
    private var predictionTask: Task<Void, Never>?

    var predictedText: String = ""
    var isCapturing = false
    var isAuthorized = false
    private(set) var isFrontCamera = true
    private(set) var isCameraBusy = false
    private static let cooldown: Duration = .milliseconds(150)

    init(appStore: AppStore) {
        self.appStore = appStore
    }

    /// Start camera + begin listening for pixel buffers. Guards against double-start and cooldown.
    func startCapture() {
        guard !isCapturing, !isCameraBusy else { return }
        isCameraBusy = true
        let stream = appStore.cameraService.pixelBufferStream
        Task { [self] in
            do {
                isAuthorized = await PermissionService.requestCamera()
                guard isAuthorized else {
                    appStore.error = .permissionDenied("camera")
                    appStore.showingError = true
                    isCameraBusy = false
                    return
                }
                isCapturing = true
                appStore.isPredicting = true
                try await appStore.cameraService.start()
                isFrontCamera =
                    await appStore.cameraService.currentPosition == .front
                isCameraBusy = false

                predictionTask = Task { [appStore, weak self] in
                    for await pixelBuffer in stream {
                        guard !Task.isCancelled else { return }
                        do {
                            let prediction = try await appStore.inferencer.predict(pixelBuffer)
                            guard prediction.confidence >= 0.4, !prediction.gestureLabel.isEmpty else {
                                continue
                            }
                            self?.predictedText = prediction.gestureLabel
                            appStore.signPredictionOutput = prediction.gestureLabel
                        } catch {
                            appStore.error = .unknown(error.localizedDescription)
                            appStore.showingError = true
                        }
                    }
                }
            } catch {
                appStore.error = .cameraUnavailable
                appStore.showingError = true
                isCapturing = false
                appStore.isPredicting = false
                isCameraBusy = false
            }
        }
    }

    /// Flip between front and back camera.
    func flipCamera() async {
        try? await appStore.cameraService.flipCamera()
        isFrontCamera = await appStore.cameraService.currentPosition == .front
    }

    /// Speak the latest prediction aloud.
    func speakPrediction() {
        let text = predictedText
        guard !text.isEmpty else { return }
        Task {
            await appStore.synthesizerService.speak(text)
            appStore.addToHistory(message: text, role: .assistantSpoke)
        }
    }

    /// Stop camera and reset. Enforces a short cooldown to prevent rapid toggles.
    func stopCapture() {
        isCapturing = false
        appStore.isPredicting = false
        predictionTask?.cancel()
        predictionTask = nil
        isCameraBusy = true
        Task {
            await appStore.inferencer.reset()
            await appStore.cameraService.stop()
            try? await Task.sleep(for: Self.cooldown)
            isCameraBusy = false
        }
    }
}
