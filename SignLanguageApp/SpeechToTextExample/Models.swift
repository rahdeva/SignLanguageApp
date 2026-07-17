//
//  Models.swift
//  SignLanguageApp
//

import Foundation

/// Satu baris transkrip yang sudah difinalisasi (bukan partial).
struct TranscriptLine: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var date: Date = .now

    var timeLabel: String {
        Self.timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "HH.mm"
        return f
    }()
}

/// Grup riwayat berdasarkan sesi (dipakai layar Riwayat).
struct HistoryGroup: Identifiable {
    let id = UUID()
    var label: String
    var items: [TranscriptLine]
}

/// Contoh kosakata domain (custom vocabulary) untuk caregiver/medis.
/// Dipakai sebagai `contextualStrings` pada SFSpeechRecognizer — istilah yang
/// rawan salah transkrip: nama obat, nama keluarga, istilah medis.
enum DomainVocabulary {
    nonisolated static let medical: [String] = [
        // Obat
        "Paracetamol", "Amlodipine", "Metformin", "Candesartan",
        "Amoxicillin", "Salbutamol", "nebulizer",
        // Istilah medis / perawatan
        "tensi", "gula darah", "fisioterapi", "oksigen",
        "kadar saturasi", "kateter", "infus",
        // Nama keluarga / panggilan (contoh)
        "Ibu Sari", "Pak Budi", "Mbak Rin", "Dokter Anwar"
    ]
}
