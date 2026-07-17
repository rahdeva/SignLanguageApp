//
//  SFSpeechCaptioner.swift
//  SignLanguageApp
//
//  Engine UTAMA untuk id-ID.
//  SFSpeechRecognizer + SFSpeechAudioBufferRecognitionRequest, partial results,
//  contextual strings (custom vocabulary), rotasi segmen agar captioning
//  terus-menerus (menghindari batas durasi ± 1 menit).
//
//  Perbaikan error 216 — April 2026:
//  - Single state enum menggantikan tiga boolean (isRunning/isRotating/isStopping)
//  - Session identifier (UUID) untuk mencegah stale callback
//  - Rotasi serial: stop → delay → start, bukan overlap
//  - Audio session mode .measurement untuk speech recognition
//  - Semua callback diverifikasi session ID sebelum diproses
//

import Foundation
import Speech
import AVFoundation
import OSLog

// MARK: - Logger

nonisolated private let sttLog = Logger(subsystem: "com.dewaayam.SignLanguageApp", category: "SFSpeechCaptioner")

// MARK: - State machine (single source of truth)

enum SpeechRecognitionState: Equatable {
    case idle
    case starting
    case listening
    case rotating
    case stopping
    case failed(String)
}

@MainActor
final class SFSpeechCaptioner: LiveCaptioner {

    static let engineName = "SFSpeechRecognizer"

    // MARK: Callbacks

    var onPartial: ((String) -> Void)?
    var onCommit: ((String) -> Void)?
    var onLevel: ((Float) -> Void)?
    var onStatus: ((CaptionEngineStatus) -> Void)?

    // MARK: Konfigurasi

    private let recognizer: SFSpeechRecognizer?
    private let contextualStrings: [String]
    private let localeID: String

    // MARK: Audio

    private let audioEngine = AVAudioEngine()
    private let sink = AudioSink()
    private var tapInstalled = false

    // MARK: Recognition session

    /// Selalu buat instance baru — tidak boleh reuse.
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// State machine — single source of truth.
    private var state: SpeechRecognitionState = .idle

    /// Setiap start() dapat UUID baru. Callback hanya diproses jika cocok.
    private var activeSessionID: UUID = UUID()

    // MARK: Segment rotation

    private var latestPartial = ""

    private let silenceCommitDelay: TimeInterval = 1.4
    private var silenceWork: DispatchWorkItem?

    private let maxSegmentDuration: TimeInterval = 50
    private var maxDurationWork: DispatchWorkItem?

    /// Delay untuk memberi waktu Speech framework release resource antar segmen.
    /// Apple tidak menyediakan API callback untuk "task fully cleaned up", jadi
    /// delay 300ms adalah pendekatan praktis yang terbukti mencegah error 216.
    private let rotationDelayNanos: UInt64 = 300_000_000

    // MARK: Low-signal detection

    private var lastLoudAt = Date()
    private var lowSignalActive = false

    // MARK: - Init

    init(locale: Locale, contextualStrings: [String] = []) {
        self.localeID = locale.identifier
        self.recognizer = SFSpeechRecognizer(locale: locale)
        self.contextualStrings = contextualStrings

        let onDevice = self.recognizer?.supportsOnDeviceRecognition ?? false
        let idIDSupported = SFSpeechRecognizer.supportedLocales().contains { $0.identifier == locale.identifier }
        sttLog.debug("""
            [Speech] Init — locale: \(locale.identifier), \
            recognizer: \(self.recognizer != nil ? "OK" : "nil"), \
            id-ID supported: \(idIDSupported), \
            onDevice: \(onDevice)
            """)
    }

    // MARK: - Prepare

    /// Panggil sekali sebelum start() pertama. Idempoten — lewati jika sudah authorized.
    func prepare() async throws {
        guard state != .listening, state != .starting else { return }
        sttLog.debug("[Speech] Prepare — begin")

        onStatus?(.preparing)

        let speech = await Self.requestSpeechAuthorization()
        guard speech == .authorized else {
            sttLog.error("[Speech] Prepare — speech permission denied")
            throw CaptionError.speechPermissionDenied
        }

        let mic = await Self.requestMicPermission()
        guard mic else {
            sttLog.error("[Speech] Prepare — mic permission denied")
            throw CaptionError.micPermissionDenied
        }

        guard let recognizer else {
            sttLog.error("[Speech] Prepare — recognizer nil for \(self.localeID)")
            throw CaptionError.localeUnsupported(localeID)
        }

        guard recognizer.isAvailable else {
            sttLog.error("[Speech] Prepare — recognizer unavailable")
            throw CaptionError.recognizerUnavailable
        }

        sttLog.debug("[Speech] Prepare — done, recognizer available: true")
    }

    // MARK: - Start

    func start() async throws {
        guard state != .listening else {
            sttLog.debug("[Speech] Start — already listening, ignored")
            return
        }
        guard state != .starting else {
            sttLog.debug("[Speech] Start — already starting, ignored")
            return
        }
        guard state != .rotating else {
            sttLog.debug("[Speech] Start — currently rotating, ignored")
            return
        }

        guard let recognizer, recognizer.isAvailable else {
            sttLog.error("[Speech] Start — recognizer unavailable")
            throw CaptionError.recognizerUnavailable
        }

        state = .starting
        sttLog.debug("[Speech] Starting session: \(UUID().uuidString.prefix(8))...")

        // Generate new session ID — callback lama akan diabaikan
        let sessionID = UUID()
        self.activeSessionID = sessionID

        // Bersihkan sesi sebelumnya jika ada (idempotent)
        cleanupInternal(sessionID: sessionID)

        // Audio session
        configureAudioSession()
        startAudioEngineIfNeeded()

        // State → listening
        state = .listening
        lastLoudAt = Date()
        lowSignalActive = false
        latestPartial = ""

        // Mulai segmen pertama
        beginSegment(with: recognizer, sessionID: sessionID)
        scheduleMaxDurationRotation()

        sttLog.debug("[Speech] Session started: \(sessionID.uuidString.prefix(8))...")
        onStatus?(.listening)
    }

    // MARK: - Stop

    func stop() {
        guard state != .idle, state != .stopping else {
            sttLog.debug("[Speech] Stop — already idle/stopping, ignored")
            return
        }

        let prevState = state
        state = .stopping
        sttLog.debug("[Speech] Stopping session (was \(String(describing: prevState)))")

        cancelTimers()

        // Commit pending partial
        if !latestPartial.isEmpty {
            commit(latestPartial)
            latestPartial = ""
            onPartial?("")
        }

        // Clean up everything
        cleanupInternal(sessionID: activeSessionID)

        state = .idle
        sttLog.debug("[Speech] Stop — done")
        onStatus?(.stopped)
    }

    // MARK: - Cleanup terpusat (idempotent, aman dipanggil berkali-kali)

    private func cleanupInternal(sessionID: UUID) {
        sttLog.debug("[Speech] Cleanup — session \(sessionID.uuidString.prefix(8))...")

        // 1. End audio request — sinyal ke framework bahwa kita selesai
        request?.endAudio()

        // 2. Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            sttLog.debug("[Speech] Cleanup — audio engine stopped")
        }

        // 3. Remove tap jika terpasang
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
            sttLog.debug("[Speech] Cleanup — tap removed")
        }

        // 4. Cancel task
        task?.cancel()

        // 5. Nil-kan semua referensi
        task = nil
        request = nil
        sink.setRequest(nil)
        latestPartial = ""

        sttLog.debug("[Speech] Cleanup — done")
    }

    // MARK: - Handle recognition result

    private func handle(
        result: SFSpeechRecognitionResult?,
        error: Error?,
        sessionID: UUID
    ) {
        // ── Stale callback guard ──
        guard sessionID == activeSessionID else {
        let staleSessionID = sessionID.uuidString.prefix(8)
        let activeID = activeSessionID.uuidString.prefix(8)
        sttLog.debug("""
            [Speech] Ignoring stale callback — session \(staleSessionID) \
            != active \(activeID)
            """)
            return
        }

        // ── Guard: jangan proses jika sedang tidak listening ──
        guard state == .listening || state == .rotating else {
            let cbState = String(describing: state)
            sttLog.debug("[Speech] Ignoring callback — state is \(cbState)")
            return
        }

        // ── Handle result ──
        if let result {
            let text = result.bestTranscription.formattedString

            if result.isFinal {
                sttLog.debug("[Speech] Final: \"\(text.prefix(60))...\"")
                commit(text)

                // Task ended naturally — cleanup references (jangan cancel)
                self.request = nil
                self.task = nil
                self.sink.setRequest(nil)

                // Schedule new segment after delay
                let recognizer = self.recognizer
                let nextSessionID = self.activeSessionID
                Task { [weak self] in
                    guard let self else { return }
                    try? await Task.sleep(nanoseconds: rotationDelayNanos)
                    self.handleNaturalFinal(sessionID: nextSessionID, recognizer: recognizer)
                }
                return
            } else {
                // Partial result
                latestPartial = text
                onPartial?(text)
                scheduleSilenceCommit(sessionID: sessionID)
            }
        }

        // ── Handle error ──
        if let error {
            let nsError = error as NSError

            let errState = String(describing: state)
            sttLog.debug("""
                [Speech] Recognition error — \
                domain: \(nsError.domain), \
                code: \(nsError.code), \
                desc: \(nsError.localizedDescription), \
                state: \(errState)
                """)

            // Expected cancellation during rotation — silent ignore
            if state == .rotating {
                return
            }

            // Expected cancellation during stop
            if state == .stopping || state == .idle {
                return
            }

            // Stale session (should not happen given first guard, but double-check)
            if sessionID != activeSessionID {
                return
            }

            // Error 216 saat listening normal — ini unexpected, log dan cleanup
            if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                sttLog.error("[Speech] Error 216 saat sesi aktif — melakukan cleanup dan report")
                state = .failed(nsError.localizedDescription)
                cleanupInternal(sessionID: activeSessionID)
                state = .idle
                onStatus?(.failed("Ada kendala saat memulai pengenalan suara. Silakan coba lagi."))
                return
            }

            // Other unexpected errors
            if state == .listening {
                sttLog.error("[Speech] Unexpected error: \(nsError.domain) \(nsError.code)")
                state = .failed(nsError.localizedDescription)
                cleanupInternal(sessionID: activeSessionID)
                state = .idle
                onStatus?(.failed("Ada kendala saat memulai pengenalan suara. Silakan coba lagi."))
            }
        }
    }

    // MARK: - Natural segment end

    private func handleNaturalFinal(sessionID: UUID, recognizer: SFSpeechRecognizer?) {
        guard sessionID == activeSessionID else {
            sttLog.debug("[Speech] NaturalFinal — stale session, ignored")
            return
        }
        guard state == .listening else {
            sttLog.debug("[Speech] NaturalFinal — not listening anymore")
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            sttLog.error("[Speech] NaturalFinal — recognizer unavailable")
            return
        }

        cancelSilenceTimer()
        maxDurationWork?.cancel()
        onPartial?("")

        sttLog.debug("[Speech] NaturalFinal — starting new segment")
        beginSegment(with: recognizer, sessionID: sessionID)
        scheduleMaxDurationRotation()
    }

    // MARK: - Force rotation (silence / max duration)

    /// Rotasi sesi: stop → delay → start.
    /// Berjalan serial di MainActor dengan structured concurrency.
    private func rotateRecognitionSession(sessionID: UUID) {
        guard sessionID == activeSessionID else {
            sttLog.debug("[Speech] Rotate — stale session, ignored")
            return
        }
        guard state == .listening else {
            sttLog.debug("[Speech] Rotate — not listening, ignored")
            return
        }

        state = .rotating
        sttLog.debug("[Speech] Rotating session: \(sessionID.uuidString.prefix(8))...")

        cancelSilenceTimer()
        maxDurationWork?.cancel()

        // Commit pending partial
        if !latestPartial.isEmpty {
            commit(latestPartial)
            latestPartial = ""
        }
        onPartial?("")

        // 1. Stop recognition task (tanpa audio stop — audio engine tetap jalan)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        sink.setRequest(nil)

        // 2. Tunggu framework release resource
        let nextSessionID = self.activeSessionID
        let recognizer = self.recognizer

        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: rotationDelayNanos)

            guard nextSessionID == self.activeSessionID else {
                sttLog.debug("[Speech] Rotate — stale after delay")
                self.state = .idle
                return
            }
            guard self.state == .rotating else {
                sttLog.debug("[Speech] Rotate — no longer rotating after delay")
                return
            }
            guard let recognizer, recognizer.isAvailable else {
                sttLog.error("[Speech] Rotate — recognizer unavailable after delay")
                self.state = .idle
                return
            }

            // 3. Start new segment
            sttLog.debug("[Speech] Rotate — starting new segment")
            self.state = .listening
            self.latestPartial = ""
            self.beginSegment(with: recognizer, sessionID: nextSessionID)
            self.scheduleMaxDurationRotation()
            sttLog.debug("[Speech] Rotate — done")
        }
    }

    // MARK: - Begin segment

    private func beginSegment(with recognizer: SFSpeechRecognizer, sessionID: UUID) {
        let req = makeRecognitionRequest(recognizer: recognizer)
        self.request = req
        sink.setRequest(req)
        latestPartial = ""

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            // recognitionTask callback di background queue.
            // Hop ke MainActor untuk akses state.
            Task { @MainActor in
                self?.handle(result: result, error: error, sessionID: sessionID)
            }
        }

        sttLog.debug("[Speech] Segment started — session \(sessionID.uuidString.prefix(8))")
    }

    /// Factory method — selalu buat instance baru.
    private func makeRecognitionRequest(recognizer: SFSpeechRecognizer) -> SFSpeechAudioBufferRecognitionRequest {
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.taskHint = .dictation

        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
            sttLog.debug("[Speech] Request — requiresOnDeviceRecognition: true")
        } else {
            req.requiresOnDeviceRecognition = false
            sttLog.debug("[Speech] Request — on-device not supported, using network")
        }

        if #available(iOS 16.0, *) {
            req.addsPunctuation = true
        }
        if !contextualStrings.isEmpty {
            req.contextualStrings = contextualStrings
            sttLog.debug("[Speech] Request — contextualStrings: \(self.contextualStrings.count) items")
        }

        return req
    }

    // MARK: - Timers

    private func scheduleSilenceCommit(sessionID: UUID) {
        cancelSilenceTimer()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.rotateRecognitionSession(sessionID: sessionID)
            }
        }
        silenceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + silenceCommitDelay, execute: work)
    }

    private func scheduleMaxDurationRotation() {
        maxDurationWork?.cancel()
        let capturedSessionID = activeSessionID
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.rotateRecognitionSession(sessionID: capturedSessionID)
            }
        }
        maxDurationWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + maxSegmentDuration, execute: work)
    }

    private func cancelSilenceTimer() {
        silenceWork?.cancel()
        silenceWork = nil
    }

    private func cancelTimers() {
        cancelSilenceTimer()
        maxDurationWork?.cancel()
        maxDurationWork = nil
    }

    // MARK: - Commit

    private func commit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onCommit?(trimmed)
    }

    // MARK: - Audio session

    /// Gunakan .record + .measurement untuk speech recognition optimal.
    /// .measurement meminimalkan processing latency dan memberikan audio mentah
    /// ke Speech framework tanpa echo cancellation atau AGC ekstra.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playAndRecord agar suara tetap keluar ke speaker (caregiver dengar diri sendiri)
            // .defaultToSpeaker memastikan audio routing ke speaker internal
            try session.setCategory(.playAndRecord,
                                    mode: .measurement,
                                    options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            sttLog.debug("[Speech] AudioSession — playAndRecord/measurement")
        } catch {
            sttLog.error("[Speech] AudioSession — failed: \(error.localizedDescription)")
            // Non-fatal — recognition mungkin tetap berjalan dengan konfigurasi default
        }
    }

    private func startAudioEngineIfNeeded() {
        let inputNode = audioEngine.inputNode
        try? inputNode.setVoiceProcessingEnabled(true)

        guard !tapInstalled else { return }

        let format = inputNode.outputFormat(forBus: 0)
        sttLog.debug("[Speech] AudioEngine — format: \(format.sampleRate)Hz, \(format.channelCount)ch")

        // Install level callback
        sink.onLevel = { [weak self] level in
            Task { @MainActor [weak self] in
                self?.handleLevel(level)
            }
        }

        // Install audio tap — hanya sekali, reuse antar segmen
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [sink] buffer, _ in
            sink.append(buffer)
            if let level = AudioSink.rms(buffer) {
                sink.onLevel?(level)
            }
        }
        tapInstalled = true
        sttLog.debug("[Speech] AudioEngine — tap installed")

        audioEngine.prepare()
        do {
            try audioEngine.start()
            sttLog.debug("[Speech] AudioEngine — started")
        } catch {
            sttLog.error("[Speech] AudioEngine — start failed: \(error.localizedDescription)")
            // Non-fatal — audio mungkin tetap bisa jalan sebagian
        }
    }

    // MARK: - Level & low-signal

    private func handleLevel(_ level: Float) {
        onLevel?(level)
        let threshold: Float = 0.015
        if level > threshold {
            lastLoudAt = Date()
            if lowSignalActive {
                lowSignalActive = false
                if state == .listening { onStatus?(.listening) }
            }
        } else if state == .listening, !lowSignalActive,
                  Date().timeIntervalSince(lastLoudAt) > 3.0,
                  latestPartial.isEmpty {
            lowSignalActive = true
            onStatus?(.lowSignal)
        }
    }

    // MARK: - Deinit

    deinit {
        sttLog.debug("[Speech] Deinit — cleanup")
        // Cleanup yang tidak memerlukan MainActor
        let capturedTask = task
        capturedTask?.cancel()

        if tapInstalled {
            // Cannot safely remove tap from deinit if engine is running
        }
    }

    // MARK: - Authorization

    private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                sttLog.debug("[Speech] Auth — speech status: \(status.rawValue)")
                cont.resume(returning: status)
            }
        }
    }

    private static func requestMicPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                sttLog.debug("[Speech] Auth — mic granted: \(granted)")
                cont.resume(returning: granted)
            }
        }
    }
}

// MARK: - AudioSink

/// Menyalurkan buffer dari thread audio real-time ke request aktif dengan aman.
/// `@unchecked Sendable` karena akses `request` dilindungi lock.
final class AudioSink: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    var onLevel: (@Sendable (Float) -> Void)?

    func setRequest(_ r: SFSpeechAudioBufferRecognitionRequest?) {
        lock.withLock { request = r }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        let r = lock.withLock { request }
        r?.append(buffer)
    }

    /// RMS level 0…1 dari channel pertama.
    static func rms(_ buffer: AVAudioPCMBuffer) -> Float? {
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return nil }
        var sum: Float = 0
        for i in 0..<n { let s = channel[i]; sum += s * s }
        return (sum / Float(n)).squareRoot()
    }
}
