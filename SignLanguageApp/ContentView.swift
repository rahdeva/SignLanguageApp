import SwiftUI
import AVFoundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - View Model

@Observable
class TranslatorViewModel {
    var activeTokens: [String] = []
    let availableTokens: [String] = [
        "saya", "kamu", "ibu", "makan", "nasi", "pergi", "mana",
        "tolong", "ambil", "air", "sakit", "kepala", "rumah", "tidur", "pulang",
        " ",
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
        "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"
    ]
    
    var generatedPrompt: String = ""
    var correctedSentence: String = ""
    var isTranslating: Bool = false
    var errorMessage: String? = nil

    
    private let translator = BISINDOTranslator()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    func addToken(_ token: String) {
        activeTokens.append(token)
        updatePrompt()
    }
    
    func removeToken(at index: Int) {
        activeTokens.remove(at: index)
        updatePrompt()
    }
    
    func clearAll() {
        activeTokens.removeAll()
        generatedPrompt = ""
        correctedSentence = ""
        errorMessage = nil
    }
    
    private func updatePrompt() {
        if activeTokens.isEmpty {
            generatedPrompt = ""
        } else {
            generatedPrompt = translator.buildPrompt(for: activeTokens)
        }
    }
    
    func translate() async {
        guard !activeTokens.isEmpty else { return }
        
        isTranslating = true
        errorMessage = nil
        correctedSentence = ""
        
        do {
            let result = try await checkFM(input: activeTokens)
            correctedSentence = result
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isTranslating = false
    }
    
    func speakResult() {
        guard !correctedSentence.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: correctedSentence)
        utterance.voice = AVSpeechSynthesisVoice(language: "id-ID")
        utterance.rate = 0.5
        
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var viewModel = TranslatorViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Title section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BISINDO AI Corrector")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.linearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        
                        Text("Simulasikan gesture ke kalimat natural menggunakan Apple Intelligence.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Selected Tokens
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Daftar Token Aktif")
                                .font(.headline)
                            Spacer()
                            if !viewModel.activeTokens.isEmpty {
                                Button("Hapus Semua") {
                                    withAnimation(.spring(duration: 0.3)) {
                                        viewModel.clearAll()
                                    }
                                }
                                .font(.caption)
                                .tint(.red)
                            }
                        }
                        
                        if viewModel.activeTokens.isEmpty {
                            ContentUnavailableView {
                                Label("Belum ada token", systemImage: "hand.raised.fill")
                            } description: {
                                Text("Pilih token di bawah untuk mulai simulasi.")
                            }
                            .frame(height: 120)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(.rect(cornerRadius: 16))
                        } else {
                            // Display selected tokens as chips
                            FlowLayout(spacing: 8) {
                                ForEach(Array(viewModel.activeTokens.enumerated()), id: \.offset) { index, token in
                                    HStack(spacing: 6) {
                                        Text(token == " " ? "[spasi]" : token)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Button {
                                            withAnimation(.spring(duration: 0.3)) {
                                                viewModel.removeToken(at: index)
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.indigo.opacity(0.15))
                                    .foregroundStyle(.indigo)
                                    .clipShape(.capsule)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(.rect(cornerRadius: 16))
                            
                            // Display merged/preprocessed result
                            let clean = BISINDOTranslator().preprocessTokens(viewModel.activeTokens)
                            if !clean.isEmpty {
                                HStack(spacing: 6) {
                                    Text("Gabungan Kata:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(clean.joined(separator: ", "))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.indigo)
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Available Tokens Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pilih Kata/Gestur")
                            .font(.headline)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.availableTokens, id: \.self) { token in
                                Button {
                                    withAnimation(.spring(duration: 0.3)) {
                                        viewModel.addToken(token)
                                    }
                                } label: {
                                    Text(token == " " ? "spasi" : token)
                                        .font(.subheadline)
                                }
                                .buttonStyle(.bordered)
                                .tint(.indigo)
                                .sensoryFeedback(.selection, trigger: viewModel.activeTokens.count)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            Task {
                                await viewModel.translate()
                            }
                        } label: {
                            HStack {
                                if viewModel.isTranslating {
                                    ProgressView()
                                        .tint(.white)
                                        .padding(.trailing, 8)
                                }
                                Text(viewModel.isTranslating ? "Menerjemahkan..." : "Koreksi Kalimat")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.activeTokens.isEmpty ? Color.gray : Color.indigo)
                            .foregroundStyle(.white)
                            .clipShape(.rect(cornerRadius: 14))
                        }
                        .disabled(viewModel.activeTokens.isEmpty || viewModel.isTranslating)
                    }
                    .padding(.horizontal)
                    
                    // Output & Prompt Engineering Debugging Card
                    if !viewModel.correctedSentence.isEmpty || viewModel.errorMessage != nil || !viewModel.generatedPrompt.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            if let error = viewModel.errorMessage {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Status Model")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(error)
                                        .font(.body)
                                        .foregroundStyle(.red)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.1))
                                .clipShape(.rect(cornerRadius: 14))
                            }
                            
                            if !viewModel.correctedSentence.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Hasil Koreksi (Natural Sentence)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.indigo)
                                    
                                    Text(viewModel.correctedSentence)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    
                                    Button {
                                        viewModel.speakResult()
                                    } label: {
                                        Label("Bacakan Kalimat", systemImage: "speaker.wave.2.fill")
                                            .fontWeight(.semibold)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.indigo)
                                    .controlSize(.regular)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.indigo.opacity(0.05))
                                .clipShape(.rect(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.indigo.opacity(0.2), lineWidth: 1)
                                )
                            }
                            
                            if !viewModel.generatedPrompt.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Prompt yang dikirim ke LLM (Debug)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    ScrollView {
                                        Text(viewModel.generatedPrompt)
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                            .padding(8)
                                    }
                                    .frame(height: 150)
                                    .background(Color(.systemBackground))
                                    .clipShape(.rect(cornerRadius: 8))
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(.rect(cornerRadius: 14))
                            }
                        }
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("CareBridge Corrector")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Flow Layout Helper
/// Custom simple layout for presenting flow tags
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxRowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width {
                currentX = 0
                currentY += maxRowHeight + spacing
                maxRowHeight = 0
            }
            maxRowHeight = max(maxRowHeight, size.height)
            currentX += size.width + spacing
        }
        
        height = currentY + maxRowHeight
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxRowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width {
                currentX = bounds.minX
                currentY += maxRowHeight + spacing
                maxRowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            maxRowHeight = max(maxRowHeight, size.height)
            currentX += size.width + spacing
        }
    }
}

#Preview {
    ContentView()
}
