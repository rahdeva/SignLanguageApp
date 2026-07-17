//
//  SpeechAnalyzerCaptioner.swift
//  SignLanguageApp
//
//  Engine iOS 26+ (SpeechAnalyzer + SpeechTranscriber).
//  Dipakai HANYA jika locale target ada di SpeechTranscriber.supportedLocales.
//  Untuk id-ID saat ini TIDAK aktif (id-ID belum didukung) — lihat faktori.
//
//  Catatan: SpeechTranscriber TIDAK punya contextual strings / custom vocabulary,
//  jadi engine ini tak menerima kosakata domain. Itu salah satu alasan id-ID
//  tetap di SFSpeechRecognizer meski SpeechAnalyzer lebih baru.
//

import Foundation
import Speech
import AVFoundation

@available(iOS 26.0, *)
@MainActor
final class SpeechAnalyzerCaptioner: LiveCaptioner {

    static let engineName = "SpeechAnalyzer + SpeechTranscriber"

    var onPartial: ((String) -> Void)?
    var onCommit: ((String) -> Void)?
    var onLevel: ((Float) -> Void)?
    var onStatus: ((CaptionEngineStatus) -> Void)?

    private let locale: Locale

    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var analyzerFormat: AVAudioFormat?

    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    private let audioEngine = AVAudioEngine()
    private var converter: BufferConverter?
    private var tapInstalled = false
    private var isRunning = false

    init(locale: Locale) {
        self.locale = locale
    }

    // MARK: - prepare (izin + unduh model)

    func prepare() async throws {
        onStatus?(.preparing)

        let speech = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speech == .authorized else { throw CaptionError.speechPermissionDenied }

        let mic = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
        guard mic else { throw CaptionError.micPermissionDenied }

        // Model bahasa on-device (sekali unduh, lalu offline).
        let supported = await SpeechTranscriber.supportedLocales
        let target = locale.identifier(.bcp47)
        guard supported.contains(where: { $0.identifier(.bcp47) == target }) else {
            throw CaptionError.localeUnsupported(locale.identifier)
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],       // partial/volatile
            attributeOptions: [.audioTimeRange]
        )
        self.transcriber = transcriber

        let installed = await SpeechTranscriber.installedLocales
        let alreadyInstalled = installed.contains { $0.identifier(.bcp47) == target }
        if !alreadyInstalled {
            onStatus?(.downloadingModel(progress: 0))
            do {
                if let req = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                    try await req.downloadAndInstall()
                }
            } catch {
                throw CaptionError.modelInstallFailed(error.localizedDescription)
            }
        }
    }

    // MARK: - start

    func start() async throws {
        guard !isRunning else { return }
        guard let transcriber else { throw CaptionError.recognizerUnavailable }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputBuilder = continuation

        // Baca hasil (partial → volatile, final → commit).
        resultsTask = Task { [weak self] in
            guard let self, let transcriber = self.transcriber else { return }
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    if result.isFinal {
                        self.onCommit?(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        self.onPartial?("")
                    } else {
                        self.onPartial?(text)
                    }
                }
            } catch {
                if self.isRunning { self.onStatus?(.failed(error.localizedDescription)) }
            }
        }

        try configureAudioSession()
        try startAudioEngine()

        try await analyzer.start(inputSequence: stream)
        isRunning = true
        onStatus?(.listening)
    }

    // MARK: - stop

    func stop() {
        guard isRunning else { return }
        isRunning = false

        audioEngine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
        audioEngine.stop()

        inputBuilder?.finish()
        inputBuilder = nil

        let analyzer = self.analyzer
        Task { try? await analyzer?.finalizeAndFinishThroughEndOfInput() }

        resultsTask?.cancel()
        resultsTask = nil
        self.analyzer = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        onStatus?(.stopped)
    }

    // MARK: - Audio

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord,
                                    mode: .voiceChat,
                                    options: [.duckOthers, .allowBluetoothHFP, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw CaptionError.audioSessionFailed(error.localizedDescription)
        }
    }

    private func startAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        try? inputNode.setVoiceProcessingEnabled(true)
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let analyzerFormat else { throw CaptionError.recognizerUnavailable }
        let converter = BufferConverter(from: inputFormat, to: analyzerFormat)
        self.converter = converter

        if !tapInstalled {
            let builder = inputBuilder
            inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { buffer, _ in
                if let out = converter.convert(buffer) {
                    builder?.yield(AnalyzerInput(buffer: out))
                }
                if let level = AudioSink.rms(buffer) {
                    Task { @MainActor in /* level UI */ _ = level }
                }
            }
            tapInstalled = true
        }

        audioEngine.prepare()
        do { try audioEngine.start() }
        catch { throw CaptionError.audioSessionFailed(error.localizedDescription) }
    }
}

// MARK: - BufferConverter

/// Konversi buffer mic ke format yang diminta SpeechAnalyzer.
/// `@unchecked Sendable`: AVAudioConverter dipakai serial dari thread audio.
@available(iOS 26.0, *)
final class BufferConverter: @unchecked Sendable {
    private let converter: AVAudioConverter?
    private let outputFormat: AVAudioFormat

    init(from input: AVAudioFormat, to output: AVAudioFormat) {
        self.outputFormat = output
        self.converter = input == output ? nil : AVAudioConverter(from: input, to: output)
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter else { return buffer } // format sudah sama
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }
        var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil ? out : nil
    }
}
