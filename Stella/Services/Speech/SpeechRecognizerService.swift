//
//  SpeechRecognizerService.swift
//  Stella
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import AVFoundation
import Speech

/// Errors thrown by `SpeechRecognizerService`.
enum SpeechError: LocalizedError {
    case unavailable
    case notAuthorized
    case recognitionFailed(Error)
    case noAudioInput

    var errorDescription: String? {
        switch self {
        case .unavailable: "Speech recognition is unavailable"
        case .notAuthorized: "Speech recognition not authorized"
        case .recognitionFailed(let error):
            "Recognition failed: \(error.localizedDescription)"
        case .noAudioInput: "No audio input available"
        }
    }
}

/// Real-time speech-to-text via `AVAudioEngine` + `SFSpeechRecognizer`.
/// Returns an async throwing stream of partial transcription strings.
actor SpeechRecognizerService {
    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognizer: SFSpeechRecognizer?
    /// Set when `stop()` is called so the recognition callback (which runs
    /// outside the actor) can treat the resulting cancellation error as a clean finish.
    nonisolated(unsafe) private var isStopping = false

    /// Start recognition for the given locale. Outputs partial results as they arrive.
    func start(locale: Locale = .current) -> AsyncThrowingStream<String, Error>
    {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard await PermissionService.requestMicrophone() else {
                        throw SpeechError.notAuthorized
                    }
                    guard await PermissionService.requestSpeech() else {
                        throw SpeechError.notAuthorized
                    }

                    let recognizer = SFSpeechRecognizer(locale: locale)
                    guard let recognizer, recognizer.isAvailable else {
                        throw SpeechError.unavailable
                    }
                    self.recognizer = recognizer
                    self.isStopping = false

                    let audioSession = AVAudioSession.sharedInstance()
                    try audioSession.setCategory(
                        .record,
                        mode: .measurement,
                        options: .duckOthers
                    )
                    try audioSession.setActive(true)

                    let inputNode = audioEngine.inputNode
                    let recordingFormat = inputNode.outputFormat(forBus: 0)
                    guard recordingFormat.sampleRate > 0 else {
                        throw SpeechError.noAudioInput
                    }

                    let request = SFSpeechAudioBufferRecognitionRequest()
                    request.shouldReportPartialResults = true
                    self.audioRequest = request

                    inputNode.installTap(
                        onBus: 0,
                        bufferSize: 1024,
                        format: recordingFormat
                    ) { buffer, _ in
                        request.append(buffer)
                    }

                    audioEngine.prepare()
                    try audioEngine.start()

                    recognitionTask = recognizer.recognitionTask(with: request)
                    { [weak self] result, error in
                        if let error {
                            let nsError = error as NSError
                            let isCancelled = nsError.domain == "kAFAssistantErrorDomain" ||
                                              nsError.code == 2160 || nsError.code == 2048 ||
                                              error.localizedDescription.localizedCaseInsensitiveContains("cancel") ||
                                              (self?.isStopping ?? false)
                            if isCancelled {
                                continuation.finish()
                            } else {
                                continuation.finish(
                                    throwing: SpeechError.recognitionFailed(error)
                                )
                            }
                            return
                        }
                        if let result {
                            continuation.yield(
                                result.bestTranscription.formattedString
                            )
                            if result.isFinal {
                                continuation.finish()
                            }
                        }
                    }

                    continuation.onTermination = { [weak self] _ in
                        Task { [weak self] in
                            await self?.cleanup()
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Cancel current recognition and release audio resources cleanly.
    func stop() {
        isStopping = true
        audioRequest?.endAudio()
        cleanup()
    }

    private func cleanup() {
        recognitionTask?.cancel()
        recognitionTask = nil
        audioRequest = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
