import Foundation

// MARK: - Domain Vocabulary (salinan untuk playground)

/// Contoh kosakata domain medis — sama dengan yang dipakai di aplikasi utama.
enum DomainVocabulary {
    static let medical: [String] = [
        "Paracetamol", "Amlodipine", "Metformin", "Candesartan",
        "Amoxicillin", "Salbutamol", "nebulizer",
        "tensi", "gula darah", "fisioterapi", "oksigen",
        "kadar saturasi", "kateter", "infus",
        "Ibu Sari", "Pak Budi", "Mbak Rin", "Dokter Anwar"
    ]
}

// MARK: - Status Engine (salinan ringan)

enum SimulatorStatus: Equatable {
    case idle
    case listening
    case lowSignal
    case stopped
    case failed(String)
}

// MARK: - CaptionSimulator

/// Simulator yang meniru perilaku `LiveCaptioner` tanpa microphone atau Speech framework.
///
/// Cara pakai:
/// ```swift
/// let sim = CaptionSimulator(contextualStrings: ["Paracetamol"])
/// sim.onPartialUpdate = { print("partial: \($0)") }
/// sim.onFinalCommit = { print("final: \($0)") }
/// sim.feedPartial("Kita")
/// sim.feedPartial("Kita sarapan")
/// sim.commitCurrent()
/// ```
class CaptionSimulator {
    /// Callback untuk partial results (volatile, kata-per-kata)
    var onPartialUpdate: ((String) -> Void)?
    /// Callback untuk final commit (satu baris caption selesai)
    var onFinalCommit: ((String) -> Void)?
    /// Callback untuk perubahan status
    var onStatusChange: ((SimulatorStatus) -> Void)?

    /// Kosakata tambahan (simulasi contextualStrings)
    let contextualStrings: [String]

    /// Akumulasi teks segmen saat ini
    private(set) var currentSegmen: String = ""
    /// Jumlah operasi simulasi sejak mulai
    private(set) var elapsed: Int = 0
    /// Status terkini
    private(set) var status: SimulatorStatus = .idle {
        didSet { onStatusChange?(status) }
    }

    /// Level audio simulasi (0…1)
    var audioLevel: Float = 0.3
    /// Apakah sinyal rendah aktif
    private(set) var isLowSignal = false
    private var lastLoudAt: Date = .now

    init(contextualStrings: [String] = []) {
        self.contextualStrings = contextualStrings
    }

    // MARK: - Simulasi Input

    /// Kirim partial result baru (simulasi caregiver bicara).
    /// Teks akan menggantikan partial sebelumnya, persis seperti SFSpeechRecognizer.
    func feedPartial(_ text: String) {
        elapsed += 1
        currentSegmen = text
        onPartialUpdate?(text)
        status = .listening

        // Reset deteksi sinyal rendah — ada aktivitas suara
        lastLoudAt = Date()
        isLowSignal = false
    }

    /// Commit segmen saat ini sebagai final (simulasi jeda bicara).
    func commitCurrent() {
        guard !currentSegmen.isEmpty else { return }
        let trimmed = currentSegmen.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onFinalCommit?(trimmed)
        currentSegmen = ""
    }

    /// Commit langsung teks tertentu (untuk pengujian).
    func commit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onFinalCommit?(trimmed)
    }

    /// Rotasi paksa segmen (simulasi batas durasi ~1 menit).
    func forceRotate() {
        if !currentSegmen.isEmpty {
            commitCurrent()
        }
        currentSegmen = ""
        elapsed = 0
    }

    /// Simulasi deteksi sinyal rendah (suara tidak terdengar).
    func simulateLowSignal(threshold: Float, duration: TimeInterval) {
        audioLevel = 0.005 // di bawah threshold
        isLowSignal = true
        status = .lowSignal
    }

    /// Mulai sesi baru
    func start() {
        status = .listening
        lastLoudAt = Date()
        isLowSignal = false
    }

    /// Hentikan sesi
    func stop() {
        if !currentSegmen.isEmpty { commitCurrent() }
        status = .stopped
    }

    /// Daftar istilah yang "didukung" oleh decoder (simulasi contextualStrings).
    /// Istilah di sini dianggap tidak akan salah transkrip.
    var supportedTerms: [String] { contextualStrings }
}

// MARK: - EngineEvaluator

/// Simulasi logika pemilihan engine (hybrid).
///
/// Di aplikasi asli, logika ini ada di `SpeechEngineFactory`:
/// - Cek `SpeechTranscriber.supportedLocales` (iOS 26+)
/// - Fallback ke `SFSpeechRecognizer` bila locale tidak didukung
enum EngineEvaluator {

    /// Daftar locale yang didukung SpeechTranscriber (simulasi status per Juli 2026).
    /// id-ID BELUM ada di daftar ini.
    static let analyzerLocales: Set<String> = [
        "ar-SA", "cmn-CN", "yue-CN",
        "en-US", "en-GB", "en-AU", "en-IN",
        "fr-FR", "fr-CA",
        "de-DE", "de-AT", "de-CH",
        "ja-JP",
        "ko-KR",
        "es-ES", "es-MX", "es-US",
        "it-IT",
        "pt-BR", "pt-PT",
        "nl-NL",
        "sv-SE",
        "da-DK",
        "nb-NO",
        "fi-FI",
        "pl-PL",
        "ro-RO",
        "tr-TR",
        "vi-VN",
        "th-TH",
        "hi-IN",
    ]

    /// Pilih engine terbaik untuk locale yang diberikan.
    static func recommendEngine(for localeID: String) -> String {
        let bcp47 = localeID.replacingOccurrences(of: "_", with: "-")
        if analyzerLocales.contains(bcp47) || analyzerLocales.contains(localeID) {
            return "SpeechAnalyzer + SpeechTranscriber"
        }
        return "SFSpeechRecognizer (dengan contextualStrings & on-device)"
    }

    /// Berikan alasan pemilihan engine.
    static func reason(for localeID: String) -> String {
        let bcp47 = localeID.replacingOccurrences(of: "_", with: "-")
        if analyzerLocales.contains(bcp47) || analyzerLocales.contains(localeID) {
            return """
            Locale \(localeID) sudah didukung oleh SpeechTranscriber (iOS 26+).
            Menggunakan SpeechAnalyzer yang lebih modern, latensi lebih rendah,
            dan segmentasi otomatis.
            """
        }
        return """
        Locale \(localeID) BELUM didukung oleh SpeechTranscriber.
        Menggunakan SFSpeechRecognizer + on-device recognition + contextualStrings
        untuk custom vocabulary domain medis.
        """
    }

    /// Semua locale yang tersedia (untuk debugging).
    static var allAnalyzerLocales: [String] {
        analyzerLocales.sorted()
    }
}

// MARK: - Helper Formatting

struct CaptionFormatter {
    /// Bersihkan whitespace berlebih, pertahankan tanda baca.
    static func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Deteksi apakah teks mengandung istilah dari kosakata domain.
    /// Berguna untuk validasi pasca-transkrip.
    static func containsDomainTerm(_ text: String, terms: [String]) -> Bool {
        let lower = text.lowercased()
        return terms.contains { lower.contains($0.lowercased()) }
    }

    /// Format timestamp untuk riwayat (HH.mm).
    static func timeLabel(from date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "HH.mm"
        return f.string(from: date)
    }
}
