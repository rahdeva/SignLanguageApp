//
//  SpeechRecognizerService.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import AVFoundation
import Speech

enum SpeechError: LocalizedError {
    case unavailable
    case notAuthorized
    case recognitionFailed(Error)
    case noAudioInput

    var errorDescription: String? {
        switch self {
        case .unavailable: "Speech recognition is unavailable"
        case .notAuthorized: "Speech recognition not authorized"
        case .recognitionFailed(let error): "Recognition failed: \(error.localizedDescription)"
        case .noAudioInput: "No audio input available"
        }
    }
}

actor SpeechRecognizerService {
    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    func start(locale: Locale = .current) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard await PermissionService.requestMicrophone() else { throw SpeechError.notAuthorized }
                    guard await PermissionService.requestSpeech() else { throw SpeechError.notAuthorized }

                    let recognizer = SFSpeechRecognizer(locale: locale)
                    guard let recognizer, recognizer.isAvailable else { throw SpeechError.unavailable }
                    self.recognizer = recognizer

                    let audioSession = AVAudioSession.sharedInstance()
                    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                    try audioSession.setActive(true)

                    let inputNode = audioEngine.inputNode
                    let recordingFormat = inputNode.outputFormat(forBus: 0)
                    guard recordingFormat.sampleRate > 0 else { throw SpeechError.noAudioInput }

                    let request = SFSpeechAudioBufferRecognitionRequest()
                    request.shouldReportPartialResults = true

                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                        request.append(buffer)
                    }

                    audioEngine.prepare()
                    try audioEngine.start()

                    recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                        if let error {
                            continuation.finish(throwing: SpeechError.recognitionFailed(error))
                            return
                        }
                        if let result {
                            continuation.yield(result.bestTranscription.formattedString)
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

    func stop() {
        cleanup()
    }

    private func cleanup() {
        recognitionTask?.cancel()
        recognitionTask = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
