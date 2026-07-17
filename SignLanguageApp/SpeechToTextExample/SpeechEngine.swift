//
//  SpeechEngine.swift
//  SignLanguageApp
//
//  Lapisan abstraksi di atas framework Speech bawaan Apple.
//
//  Keputusan teknis (lihat dokumen solusi):
//  - Bahasa Indonesia (id-ID) DIDUKUNG oleh SFSpeechRecognizer, TAPI TIDAK ada
//    di SpeechTranscriber.supportedLocales (iOS 26). Karena itu engine default
//    untuk id-ID adalah SFSpeechRecognizer.
//  - SpeechAnalyzer/SpeechTranscriber (iOS 26+) dipakai HANYA bila locale target
//    memang tersedia di sana (mis. nanti Apple menambah id-ID). Faktori di bawah
//    memilih otomatis → strategi "versioning" tanpa ubah UI.
//

import Foundation
import Speech
import OSLog

// MARK: - Logger

let sttLogger = Logger(subsystem: "com.dewaayam.SignLanguageApp", category: "SpeechEngine")

// MARK: - Status & error

enum CaptionEngineStatus: Equatable {
    case idle
    case preparing            // minta izin / cek model
    case downloadingModel(progress: Double)
    case listening
    case lowSignal            // suara belum terdengar jelas (noisy / jauh)
    case stopped
    case failed(String)
}

enum CaptionError: LocalizedError {
    case recognizerUnavailable
    case localeUnsupported(String)
    case onDeviceUnavailable(String)
    case speechPermissionDenied
    case micPermissionDenied
    case audioSessionFailed(String)
    case modelInstallFailed(String)

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Pengenalan suara sedang tidak tersedia. Coba lagi sebentar."
        case .localeUnsupported(let id):
            return "Bahasa \(id) belum didukung di perangkat ini."
        case .onDeviceUnavailable(let id):
            return "Pengenalan on-device untuk \(id) belum tersedia di perangkat ini."
        case .speechPermissionDenied:
            return "Izin pengenalan suara belum diberikan."
        case .micPermissionDenied:
            return "Izin mikrofon belum diberikan."
        case .audioSessionFailed(let m):
            return "Gagal menyiapkan audio: \(m)"
        case .modelInstallFailed(let m):
            return "Gagal menyiapkan model bahasa: \(m)"
        }
    }
}

/// Petakan error dari Speech framework ke pesan yang ramah pengguna.
func mapSpeechError(_ error: Error) -> String {
    let nsError = error as NSError
    sttLogger.debug("mapSpeechError — domain: \(nsError.domain), code: \(nsError.code)")

    if nsError.domain == "kAFAssistantErrorDomain" {
        switch nsError.code {
        case 216:
            return "Ada kendala saat memulai pengenalan suara. Silakan coba lagi."
        case 203:
            return "Koneksi internet diperlukan untuk pengenalan suara. Periksa koneksi Anda."
        case 1100:
            return "Terjadi kesalahan jaringan. Silakan coba lagi."
        case 1101:
            return "Waktu permintaan habis. Silakan coba lagi."
        default:
            return "Ada kendala saat memulai pengenalan suara. Silakan coba lagi."
        }
    }

    if nsError.domain == "com.apple.speech.SFSpeechRecognizerError" {
        return "Pengenalan suara tidak tersedia saat ini. Coba lagi sebentar."
    }

    return "Ada kendala saat memulai pengenalan suara. Silakan coba lagi."
}

// MARK: - Protokol engine

/// Antarmuka umum agar UI tidak peduli engine mana yang dipakai.
/// Callback dipanggil di MainActor.
@MainActor
protocol LiveCaptioner: AnyObject {
    /// Teks partial/volatile — berubah kata-per-kata saat masih bicara.
    var onPartial: ((String) -> Void)? { get set }
    /// Satu segmen selesai (final) → jadi satu baris caption + masuk riwayat.
    var onCommit: ((String) -> Void)? { get set }
    /// Level audio 0…1 (untuk waveform & deteksi "suara belum jelas").
    var onLevel: ((Float) -> Void)? { get set }
    /// Perubahan status engine.
    var onStatus: ((CaptionEngineStatus) -> Void)? { get set }

    /// Nama engine untuk keperluan debug/telemetry.
    static var engineName: String { get }

    /// Siapkan izin & (bila perlu) unduh model. Panggil sekali sebelum start.
    func prepare() async throws
    /// Mulai mendengarkan. Idempoten bila sudah berjalan.
    func start() async throws
    /// Berhenti; segmen partial terakhir difinalisasi lalu di-commit.
    func stop()
}

// MARK: - Laporan kapabilitas (dipakai di UI diagnostik/Pengaturan)

struct SpeechCapabilityReport {
    let localeIdentifier: String
    let sfSupportsLocale: Bool
    let sfSupportsOnDevice: Bool
    let analyzerSupportsLocale: Bool      // SpeechTranscriber.supportedLocales
    let analyzerAvailableOnOS: Bool       // iOS 26+
    let chosenEngine: String

    /// Ringkasan yang ramah untuk ditampilkan.
    var summary: String {
        var lines: [String] = []
        lines.append("Locale: \(localeIdentifier)")
        lines.append("SFSpeechRecognizer support: \(sfSupportsLocale ? "ya" : "tidak")")
        lines.append("  • on-device: \(sfSupportsOnDevice ? "ya" : "tidak (server)")")
        lines.append("SpeechTranscriber support: \(analyzerAvailableOnOS ? (analyzerSupportsLocale ? "ya" : "tidak") : "butuh iOS 26+")")
        lines.append("Engine terpilih: \(chosenEngine)")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Faktori (strategi hybrid / versioning)

enum SpeechEngineFactory {

    /// Apakah SpeechTranscriber (iOS 26+) mendukung locale ini?
    /// Async karena `supportedLocales` diambil dari sistem.
    static func analyzerSupports(locale: Locale) async -> Bool {
        guard #available(iOS 26.0, *) else { return false }
        let supported = await SpeechTranscriber.supportedLocales
        let target = locale.identifier(.bcp47)
        return supported.contains { $0.identifier(.bcp47) == target }
    }

    /// Susun laporan kapabilitas untuk locale tertentu.
    static func capabilityReport(localeIdentifier: String) async -> SpeechCapabilityReport {
        let locale = Locale(identifier: localeIdentifier)
        let sf = SFSpeechRecognizer(locale: locale)
        let sfSupportsLocale = SFSpeechRecognizer.supportedLocales()
            .contains { $0.identifier == locale.identifier }
        let sfOnDevice = sf?.supportsOnDeviceRecognition ?? false
        let analyzerOS: Bool = { if #available(iOS 26.0, *) { return true } else { return false } }()
        let analyzerLocale = await analyzerSupports(locale: locale)

        let chosen: String
        if #available(iOS 26.0, *), analyzerLocale {
            chosen = SpeechAnalyzerCaptioner.engineName
        } else {
            chosen = SFSpeechCaptioner.engineName
        }

        sttLogger.debug("""
            capabilityReport — locale: \(localeIdentifier), \
            sfSupports: \(sfSupportsLocale), \
            sfOnDevice: \(sfOnDevice), \
            analyzerLocale: \(analyzerLocale), \
            chosen: \(chosen)
            """)

        return SpeechCapabilityReport(
            localeIdentifier: localeIdentifier,
            sfSupportsLocale: sfSupportsLocale,
            sfSupportsOnDevice: sfOnDevice,
            analyzerSupportsLocale: analyzerLocale,
            analyzerAvailableOnOS: analyzerOS,
            chosenEngine: chosen
        )
    }

    /// Pilih engine terbaik untuk locale.
    /// - SpeechAnalyzer jika iOS 26+ DAN locale ada di supportedLocales.
    /// - Selain itu SFSpeechRecognizer (ini kasus id-ID saat ini).
    @MainActor
    static func make(
        localeIdentifier: String = "id-ID",
        contextualStrings: [String] = DomainVocabulary.medical
    ) async -> LiveCaptioner {
        let locale = Locale(identifier: localeIdentifier)
        let supportsAnalyzer = await analyzerSupports(locale: locale)

        sttLogger.debug("""
            make — locale: \(localeIdentifier), \
            analyzerSupports: \(supportsAnalyzer)
            """)

        if #available(iOS 26.0, *), supportsAnalyzer {
            sttLogger.debug("make — choosing SpeechAnalyzerCaptioner")
            return SpeechAnalyzerCaptioner(locale: locale)
        }

        sttLogger.debug("make — choosing SFSpeechCaptioner")
        return SFSpeechCaptioner(locale: locale, contextualStrings: contextualStrings)
    }
}
