/*:
 # SpeechToTextExample — Playground Eksperimen

 Playground ini menyediakan **lingkungan simulasi** untuk menguji logika
 Speech-to-Text tanpa perlu microphone, izin, atau lifecycle aplikasi penuh.

 ## Yang bisa dicoba:
 1. **Simulasi partial results** — lihat bagaimana teks diperbarui kata-per-kata.
 2. **Simulasi commit & history** — bagaimana baris final masuk ke riwayat.
 3. **Formatting caption** — pembersihan whitespace, deteksi sinyal rendah.
 4. **Pemilihan engine** — logika hybrid SFSpeechRecognizer vs SpeechAnalyzer.
 5. **Custom vocabulary** — dampak contextualStrings pada akurasi.

 ## Cara pakai
 Buka `Sources/SpeechToTextExampleSimulator.swift` untuk melihat implementasi
 mock engine dan helper. Jalankan contoh di bawah untuk melihat hasil simulasi.
 */
import Foundation

// MARK: - Contoh 1: Simulasi Partial Results

print("─── Contoh 1: Partial Results (kata-per-kata) ───")

let simulator = CaptionSimulator()
simulator.onPartialUpdate = { text in
    // Ini yang akan muncul di UI sebagai teks volatile
    print("  partial: \"\(text)\"")
}
simulator.onFinalCommit = { text in
    // Ini yang masuk ke riwayat caption
    print("  ✅ final:  \"\(text)\"")
}

// Simulasikan caregiver berbicara kalimat pendek
simulator.feedPartial("Kita")
simulator.feedPartial("Kita sarapan")
simulator.feedPartial("Kita sarapan dulu")
simulator.feedPartial("Kita sarapan dulu ya")
simulator.commitCurrent() // jeda bicara → commit

simulator.feedPartial("Obatnya")
simulator.feedPartial("Obatnya sudah")
simulator.feedPartial("Obatnya sudah diminum")
simulator.feedPartial("Obatnya sudah diminum belum")
simulator.commitCurrent()

print("")

// MARK: - Contoh 2: Custom Vocabulary & Akurasi

print("─── Contoh 2: Dampak Contextual Strings ───")

let withVocab = CaptionSimulator(contextualStrings: DomainVocabulary.medical)
withVocab.onFinalCommit = { print("  dengan vocab: \($0)") }
withVocab.feedPartial("Tolong ambilkan")
withVocab.feedPartial("Tolong ambilkan salbutamol")
withVocab.commitCurrent()

let withoutVocab = CaptionSimulator() // tanpa contextual strings
withoutVocab.onFinalCommit = { print("  tanpa vocab:  \($0)") }
withoutVocab.feedPartial("Tolong ambilkan")
withoutVocab.feedPartial("Tolong ambilkan salbu ta mol") // model default mungkin salah dengar
withoutVocab.commitCurrent()

print("")

// MARK: - Contoh 3: Durasi Segmen & Rotasi

print("─── Contoh 3: Rotasi Segmen ───")

let segmen = CaptionSimulator()
segmen.onPartialUpdate = { _ in }
segmen.onFinalCommit = { print("  commit: \($0)") }

// Satu segmen panjang (simulasi batas ~1 menit)
for detik in 0..<12 {
    let kata = ["satu", "dua", "tiga", "empat", "lima"][detik % 5]
    segmen.feedPartial("Kalimat ke-\(detik + 1) kata \(kata)")
}
print("  → rotasi setelah \(segmen.elapsed) dtk (simulasi)")
segmen.forceRotate()

print("")

// MARK: - Contoh 4: Pemilihan Engine (Hybrid)

print("─── Contoh 4: Logika Hybrid Engine ───")

let localeID = "id-ID"
let recommendation = EngineEvaluator.recommendEngine(for: localeID)
print("  Locale: \(localeID)")
print("  Rekomendasi: \(recommendation)")
print("  Alasan: \(EngineEvaluator.reason(for: localeID))")

print("")

// MARK: - Contoh 5: Formatting & Edge Cases

print("─── Contoh 5: Formatting & Edge Cases ───")

let edgeSim = CaptionSimulator()
edgeSim.onFinalCommit = { print("  \"\($0)\"") }

// Baris kosong / hanya spasi → harus dilewati
edgeSim.commit("   ")         // empty
edgeSim.commit("")            // empty
edgeSim.commit("Halo")        // valid

// Kalimat dengan spasi berlebih
edgeSim.commit("  Halo   apa   kabar  ")

// Simulasi low signal
print("  Level audio: \(edgeSim.audioLevel)")
edgeSim.simulateLowSignal(threshold: 0.015, duration: 5.0)
print("  Low signal setelah 5 dtk: \(edgeSim.isLowSignal)")

print("")
print("─── Selesai ───")
print("Buka Sources/SpeechToTextExampleSimulator.swift untuk melihat detail implementasi mock.")
