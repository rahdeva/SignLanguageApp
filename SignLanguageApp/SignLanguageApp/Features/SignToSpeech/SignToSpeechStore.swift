//
//  SignToSpeechStore.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import AVFoundation
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
    private(set) var isFrontCamera = true

    init(appStore: AppStore) {
        self.appStore = appStore
    }

    func startCapture() {
        guard !isCapturing else { return }
        let stream = appStore.cameraService.pixelBufferStream
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
                isFrontCamera = await appStore.cameraService.currentPosition == .front

                predictionTask = Task { [appStore, weak self] in
                    for await _ in stream {
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

    func flipCamera() async {
        try? await appStore.cameraService.flipCamera()
        isFrontCamera = await appStore.cameraService.currentPosition == .front
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
