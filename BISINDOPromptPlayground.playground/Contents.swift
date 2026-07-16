import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - BISINDO Context Corrector using Apple Foundation Models
// Demonstrates how to translate raw BISINDO gesture tokens into a natural sentence.

struct BISINDOTranslator {
    let systemPrompt = """
    Anda adalah penerjemah BISINDO (Bahasa Isyarat Indonesia) ke Bahasa Indonesia yang natural dan grammatically correct.
    Tugas Anda:
    1. Mengubah urutan kata kunci (tokens) kasar hasil deteksi kamera menjadi kalimat lengkap.
    2. Menambahkan kata hubung, kata depan (di, ke, dari), imbuhan, atau kata bantu yang hilang agar terdengar sopan dan alami.
    3. Mempertahankan maksud asli tanpa menambah informasi di luar konteks.
    4. Menghasilkan HANYA kalimat akhir. Jangan beri penjelasan atau pengantar.
    """
    
    let examples = [
        (input: ["saya", "makan", "nasi"], output: "Saya sedang makan nasi."),
        (input: ["kamu", "pergi", "mana"], output: "Kamu mau pergi ke mana?"),
        (input: ["tolong", "ambil", "air"], output: "Tolong ambilkan saya air minum."),
        (input: ["saya", "sakit", "kepala"], output: "Kepala saya terasa sakit."),
        (input: ["ibu", "rumah", "pulang"], output: "Ibu sudah pulang ke rumah.")
    ]
    
    /// Construct prompt for LLM
    func buildPrompt(for tokens: [String]) -> String {
        var prompt = "\(systemPrompt)\n\n"
        prompt += "Contoh penerjemahan:\n"
        for example in examples {
            prompt += "Input: \(example.input.joined(separator: ", "))\n"
            prompt += "Output: \(example.output)\n\n"
        }
        prompt += "Sekarang terjemahkan input berikut:\n"
        prompt += "Input: \(tokens.joined(separator: ", "))\n"
        prompt += "Output:"
        return prompt
    }
    
    /// Corrects BISINDO tokens using Apple Intelligence on-device model
    func translateOnDevice(tokens: [String]) async throws -> String {
        let prompt = buildPrompt(for: tokens)
        
        #if canImport(FoundationModels)
        // Check model availability on-device
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw NSError(domain: "BISINDOTranslator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence model not available/downloaded yet."])
        }
        
        // Create language model session and get response
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        
        // Clean up the output if model outputs leading/trailing whitespaces or quotes
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        #else
        // Fallback simulation for platforms without FoundationModels support (e.g. older SDKs, command line tools)
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s mock latency
        return "Saya ingin pulang ke rumah untuk tidur." // Mock output for ["saya", "rumah", "tidur"]
        #endif
    }
}

// MARK: - Executing Simulation

@main
struct MainApp {
    static func main() async {
        let translator = BISINDOTranslator()
        let rawTokens = ["saya", "rumah", "tidur"]
        
        print("Tokens: \(rawTokens)")
        print("Generating correction...")
        
        do {
            let result = try await translator.translateOnDevice(tokens: rawTokens)
            print("Result: \"\(result)\"")
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
}
