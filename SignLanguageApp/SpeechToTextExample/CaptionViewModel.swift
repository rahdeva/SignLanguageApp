//
//  CaptionViewModel.swift
//  SignLanguageApp
//

import SwiftUI
import Speech
import AVFoundation
import Observation
import OSLog

private let vmLog = Logger(subsystem: "com.dewaayam.SignLanguageApp", category: "CaptionViewModel")

enum AppPhase: Equatable {
    case permission          // izin belum diberikan
    case preparing           // sedang minta izin / siap-siap
    case ready               // siap dipakai
    case error(String)
}

enum Screen { case home, history, settings }

@Observable
@MainActor
final class CaptionViewModel {

    // MARK: - Navigation & phase

    var phase: AppPhase
    var screen: Screen = .home

    // MARK: - Caption

    var isListening = false
    var transcript: [TranscriptLine] = []
    var partial: String = ""
    var audioLevel: Float = 0
    var isLowSignal = false

    // MARK: - Settings

    var theme: AppTheme = .light
    var fontScale: Double = 1.0

    // MARK: - Diagnostics

    var capability: SpeechCapabilityReport?

    // MARK: - History

    private var sessionLines: [TranscriptLine] = []

    private let localeID = "id-ID"
    private var engine: LiveCaptioner?
    private var isStarting = false     // guard against re-entrant start()

    var captionPointSize: CGFloat { Metrics.baseCaptionSize * fontScale }
    var hasContent: Bool { !transcript.isEmpty || !partial.isEmpty }
    var palette: Palette { Palette(theme: theme) }

    init() {
        self.phase = Self.currentPhase()
        vmLog.debug("init — phase: \(String(describing: self.phase))")
    }

    static func currentPhase() -> AppPhase {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let mic = AVAudioApplication.shared.recordPermission
        if speech == .authorized && mic == .granted {
            return .ready
        }
        return .permission
    }

    // MARK: - Bootstrap

    /// Bangun engine (memilih SF / Analyzer otomatis) & muat laporan kapabilitas.
    /// Panggil sekali di awal.
    func bootstrap() async {
        vmLog.debug("bootstrap — start")
        capability = await SpeechEngineFactory.capabilityReport(localeIdentifier: localeID)
        if engine == nil {
            let engine = await SpeechEngineFactory.make(localeIdentifier: localeID)
            wire(engine)
            self.engine = engine
            vmLog.debug("bootstrap — engine: \(type(of: engine).engineName)")
        }
        if Self.currentPhase() == .ready {
            phase = .ready
            vmLog.debug("bootstrap — phase: ready")
        }
    }

    private func wire(_ engine: LiveCaptioner) {
        engine.onPartial = { [weak self] text in
            self?.partial = text
        }
        engine.onCommit = { [weak self] text in
            self?.appendFinal(text)
        }
        engine.onLevel = { [weak self] level in
            self?.audioLevel = level
        }
        engine.onStatus = { [weak self] status in
            self?.apply(status)
        }
        vmLog.debug("wire — callbacks attached")
    }

    private func appendFinal(_ text: String) {
        guard !text.isEmpty else { return }
        vmLog.debug("appendFinal — \"\(text.prefix(80))...\"")
        let line = TranscriptLine(text: text)
        transcript.append(line)
        sessionLines.insert(line, at: 0)
    }

    private func apply(_ status: CaptionEngineStatus) {
        switch status {
        case .idle, .stopped:
            isListening = false
            isLowSignal = false
        case .preparing:
            phase = .preparing
        case .downloadingModel:
            // Silently ignored — no download screen shown
            vmLog.debug("apply — downloadingModel (ignored)")
            break
        case .listening:
            phase = .ready
            isListening = true
            isLowSignal = false
        case .lowSignal:
            isLowSignal = true
        case .failed(let message):
            isListening = false
            phase = .error(message)
            vmLog.error("apply — failed: \(message)")
        }
    }

    // MARK: - Start

    func start() async {
        guard !isStarting else {
            vmLog.debug("start — already starting, ignored")
            return
        }
        guard !isListening else {
            vmLog.debug("start — already listening, ignored")
            return
        }

        isStarting = true
        defer { isStarting = false }

        let startPhase = String(describing: phase)
        let startEngine = engine != nil ? "non-nil" : "nil"
        let startPerm = String(describing: Self.currentPhase())
        vmLog.debug("""
            start — \
            phase: \(startPhase), \
            engine: \(startEngine), \
            permission: \(startPerm)
            """)

        // Bootstrap if needed
        if engine == nil {
            await bootstrap()
        }

        // Handle permissions
        if Self.currentPhase() != .ready {
            await requestPermissionAndStart()
            return
        }

        // Prepare (authorization check) then start
        do {
            try await engine?.prepare()
            vmLog.debug("start — prepare done")
            try await engine?.start()
            vmLog.debug("start — engine started")
        } catch let error as CaptionError {
            vmLog.error("start — CaptionError: \(error.localizedDescription)")
            phase = .error(error.errorDescription ?? "Ada kendala. Silakan coba lagi.")
        } catch {
            vmLog.error("start — error: \(error.localizedDescription)")
            let nsError = error as NSError
            vmLog.error("start — domain: \(nsError.domain), code: \(nsError.code)")
            phase = .error(mapSpeechError(error))
        }
    }

    // MARK: - Permission & Start (from PermissionView)

    func requestPermissionAndStart() async {
        phase = .preparing
        vmLog.debug("requestPermissionAndStart — begin")

        do {
            if engine == nil { await bootstrap() }
            try await engine?.prepare()
            vmLog.debug("requestPermissionAndStart — prepare done")
            phase = .ready
            await start()
        } catch let error as CaptionError {
            vmLog.error("requestPermissionAndStart — CaptionError: \(error.localizedDescription)")
            phase = .error(error.errorDescription ?? "Ada kendala. Silakan coba lagi.")
        } catch {
            vmLog.error("requestPermissionAndStart — error: \(error.localizedDescription)")
            phase = .error(mapSpeechError(error))
        }
    }

    // MARK: - Stop

    func stop() {
        vmLog.debug("stop — begin")
        engine?.stop()
        partial = ""
        isLowSignal = false
        isListening = false
    }

    // MARK: - Toggle

    func toggle() async {
        isListening ? stop() : await start()
    }

    // MARK: - Retry

    func retryFromError() async {
        vmLog.debug("retryFromError — begin")
        phase = .ready
        await start()
    }

    // MARK: - Navigation

    func go(_ screen: Screen) {
        if screen != .home && isListening { stop() }
        self.screen = screen
    }

    // MARK: - History

    var historyGroups: [HistoryGroup] {
        var groups: [HistoryGroup] = []
        if !sessionLines.isEmpty {
            groups.append(HistoryGroup(label: "Sesi sekarang", items: sessionLines))
        }
        groups.append(contentsOf: Self.sampleHistory)
        return groups
    }

    private static let sampleHistory: [HistoryGroup] = [
        HistoryGroup(label: "Hari ini · 14.20", items: [
            TranscriptLine(text: "Kita sarapan dulu ya, sebentar lagi."),
            TranscriptLine(text: "Obatnya sudah diminum belum?"),
            TranscriptLine(text: "Nanti sore kita jalan-jalan ke taman.")
        ]),
        HistoryGroup(label: "Hari ini · 09.05", items: [
            TranscriptLine(text: "Selamat pagi, apa kabar hari ini?"),
            TranscriptLine(text: "Aku ambilkan air minum, tunggu sebentar.")
        ])
    ]

    let availableThemes = AppTheme.allCases
}
