//
//  SpeechSynthesizerService.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import AVFAudio

actor SpeechSynthesizerService {
    private let synthesizer = AVSpeechSynthesizer()
    private let delegate = SpeechSynthesizerDelegate()
    private var continuation: CheckedContinuation<Void, Never>?

    init() {
        synthesizer.delegate = delegate
    }

    func speak(_ text: String, voice: AVSpeechSynthesisVoice? = nil) async {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice =
            voice ?? .init(language: "id-ID") ?? .init(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default
        )
        try? AVAudioSession.sharedInstance().setActive(true)

        await withCheckedContinuation { [delegate] continuation in
            delegate.continuation = continuation
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        continuation?.resume()
        continuation = nil
    }

    var isSpeaking: Bool { synthesizer.isSpeaking }
}

// MARK: - Delegate (NSObject required for AVSpeechSynthesizerDelegate)

private final class SpeechSynthesizerDelegate: NSObject,
    AVSpeechSynthesizerDelegate
{
    var continuation: CheckedContinuation<Void, Never>?

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        continuation?.resume()
        continuation = nil
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        continuation?.resume()
        continuation = nil
    }
}
