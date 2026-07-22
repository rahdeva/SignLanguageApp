//
//  SignToSpeechView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//  Updated by Antigravity to unify with multi-modal CoreML vision & sentence engine.
//

import AVFoundation
import SwiftUI

struct SignToSpeechView: View {
    @Environment(AppStore.self) private var appStore
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var recognizer = SignRecognitionEngine(
        stableThreshold: 2, cooldownThreshold: 5, maxWords: 12
    )
    @State private var showConfidenceDetails: Bool = true
    private let availableWords = [
        "Saya", "Lagi", "Makan", "Dengar", "Motor", "Belajar", "Cari", "Hari",
        "Ingat", "Maaf", "Terima kasih", "Tuli", "Apa", "Siapa", "Kapan", "Di mana",
        "Mengapa", "Bagaimana", "Merah", "Kuning", "Hijau", "Hitam", "Berangkat",
        "Datang", "Teman", "Keluarga", "Rumah", "Pagi", "Siang", "Sore", "Malam", "Air"
    ]

    // Helper to clean and translate any sign label for UI display and TTS
    private func displaySign(for raw: String) -> String {
        if raw == "Detecting..." || raw == "Uncertain" {
            return raw == "Detecting..."
                ? "sign.detecting".localized(for: appStore.languageSettings.appLanguage)
                : "sign.uncertain".localized(for: appStore.languageSettings.appLanguage)
        }
        let cleaned = SignRecognitionEngine.cleanLabel(raw)
        return SignLabelTranslator.translate(cleaned, to: appStore.languageSettings.ttsLanguage)
    }

    // Feed new inference results into the recognition engine.
    // Translates the raw Indonesian label to English when ttsLanguage == .english.
    private func handleNewSign(_ sign: String, confidence: Double) {
        guard sign != "Detecting...", sign != "Uncertain" else { return }
        let translated = displaySign(for: sign)
        Task { @MainActor in
            recognizer.targetLanguage = appStore.languageSettings.ttsLanguage
            recognizer.conversationContext = ConversationContextService.buildContextString(
                from: appStore.conversationHistory,
                currentSpeaker: .userSigned
            )
            recognizer.feed(rawLabel: translated, confidence: confidence)
        }
    }

    var body: some View {
        ZStack {
            // MARK: - Camera & Skeleton Overlay
            if cameraManager.permissionGranted {
                ZStack {
                    CameraPreviewView(
                        session: cameraManager.session,
                        isFrontCamera: cameraManager.isFrontCamera,
                        cameraManager: cameraManager
                    )

                    HandOverlayView(handPoints: cameraManager.handPoints)
                }
                .ignoresSafeArea()
            } else {
                permissionDeniedView
            }

            // MARK: - Floating UI Overlays
            VStack(spacing: 0) {
                topNavigationBar
                    .padding(.horizontal)
                    .padding(.top, 10)

                Spacer()

                VStack(spacing: 12) {
                    // Word sequence chips
                    if !recognizer.wordSequence.isEmpty {
                        wordSequenceRow
                            .padding(.horizontal)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Sentence panel — auto-appears when a sentence is ready
                    if !recognizer.builtSentence.isEmpty || recognizer.isBuildingSentence {
                        sentencePanel
                            .padding(.horizontal)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Bottom detection card
                    bottomPredictionCard
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: appStore.conversationHistory) { _, history in
            recognizer.conversationContext = ConversationContextService.buildContextString(
                from: history,
                currentSpeaker: .userSigned
            )
        }
        .onChange(of: cameraManager.currentSign) { _, newSign in
            handleNewSign(newSign, confidence: cameraManager.currentConfidence)
        }
    }

    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(cameraManager.bufferCount == 60 ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                    .shadow(color: cameraManager.bufferCount == 60 ? .green : .orange, radius: 4)
                Text("sign.app_badge", tableName: "Localizable")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)))

            Spacer()

            HStack(spacing: 8) {
                if cameraManager.bufferCount < 60 {
                    ProgressView(value: Double(cameraManager.bufferCount), total: 60.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                        .frame(width: 50)
                    Text("\(cameraManager.bufferCount)/60")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                } else {
                    Text("sign.live", tableName: "Localizable")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.green))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)))

            HStack(spacing: 10) {
                Button(action: { withAnimation(.spring()) { cameraManager.resetBuffer() } }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                // Model mode toggle: Hand Only ↔ Multi-Modal
                Button(action: {
                    withAnimation(.spring()) {
                        cameraManager.switchModel(
                            cameraManager.modelMode == .handOnly ? .multiModal : .handOnly
                        )
                    }
                }) {
                    let isMulti = cameraManager.modelMode == .multiModal
                    Image(systemName: cameraManager.modelMode.sfSymbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isMulti ? .cyan : .white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().stroke(
                            isMulti ? Color.cyan.opacity(0.5) : Color.white.opacity(0.2),
                            lineWidth: 1
                        ))
                }
                // Flip camera button
                Button(action: { withAnimation(.spring()) { cameraManager.toggleCamera() } }) {
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Word Sequence Row
    private var wordSequenceRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label(LocalizedStringKey("sign.words_detected"), systemImage: "text.word.spacing")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(.secondary)

                Spacer()

                // Silence countdown arc — fills up as the auto-build timer runs
                if recognizer.silenceProgress > 0 {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: CGFloat(recognizer.silenceProgress))
                            .stroke(
                                LinearGradient(colors: [.cyan, .purple],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 22, height: 22)
                    .animation(.linear(duration: 0.05), value: recognizer.silenceProgress)
                }


                // Undo last word
                Button(action: { withAnimation { recognizer.removeLastWord() } }) {
                    Image(systemName: "delete.backward")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                // Clear all
                Button(action: { withAnimation { recognizer.clearAll() } }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(recognizer.wordSequence.enumerated()), id: \.element.id) { idx, word in
                        wordChip(word.text, index: idx)
                    }
                }
                .padding(.vertical, 2)
            }

            Divider()
                .background(Color.white.opacity(0.15))
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("DEBUG MANUAL OVERRIDE (TAP UNTUK MENAMBAH)")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableWords, id: \.self) { word in
                            Button {
                                recognizer.addWordManually(word)
                            } label: {
                                Text(word)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color.cyan.opacity(0.12)))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.cyan.opacity(0.25), lineWidth: 1))
        )
    }

    private func wordChip(_ text: String, index: Int) -> some View {
        let hues: [Color] = [.cyan, .mint, .teal, .indigo, .purple]
        let color = hues[index % hues.count]
        return Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
                    .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
            )
    }

    // MARK: - Sentence Panel
    private var sentencePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(LocalizedStringKey("sign.sentence_label"), systemImage: "text.bubble.fill")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(.secondary)

                Spacer()

                // Dismiss / clear sentence
                Button(action: { withAnimation { recognizer.clearAll() } }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }

            if recognizer.isBuildingSentence {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.cyan)
                    Text("sign.sentence_building", tableName: "Localizable")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                }
            } else if !recognizer.builtSentence.isEmpty {
                Text(recognizer.builtSentence)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))

                HStack(spacing: 8) {
                    Button(action: {
                        UIPasteboard.general.string = recognizer.builtSentence
                    }) {
                        Label(LocalizedStringKey("sign.copy"), systemImage: "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.cyan)

                    Spacer()

                    Button(action: { recognizer.buildSentence() }) {
                        Label(LocalizedStringKey("sign.retry"), systemImage: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.cyan.opacity(0.7))
                }
            } else if let err = recognizer.sentenceError {
                Text("⚠️ \(err)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.orange)
            } else {
                Text("sign.sentence_auto", tableName: "Localizable")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [.cyan.opacity(0.4), .purple.opacity(0.2)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    ))
        )
    }

    // MARK: - Bottom Prediction Card
    private var bottomPredictionCard: some View {
        VStack(spacing: 14) {
            // Main Action Title
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("sign.detected_title", tableName: "Localizable")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundColor(.secondary)

                    Text(displaySign(for: cameraManager.currentSign).uppercased())
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(
                            cameraManager.currentSign == "Uncertain" ||
                            cameraManager.currentSign == "Detecting..." ? .yellow : .cyan
                        )
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .animation(.easeInOut(duration: 0.2), value: cameraManager.currentSign)
                }

                Spacer()

                // Confidence Ring
                ZStack {
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 5)
                        .frame(width: 60, height: 60)
                    Circle()
                        .trim(from: 0, to: CGFloat(cameraManager.currentConfidence))
                        .stroke(
                            LinearGradient(colors: [.yellow, .green, .cyan],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.25), value: cameraManager.currentConfidence)
                    VStack(spacing: 0) {
                        Text("\(Int(cameraManager.currentConfidence * 100))%")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                        Text("sign.conf", tableName: "Localizable")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }


            // Top Predictions Breakdown
            if !cameraManager.topPredictions.isEmpty {
                Divider().background(Color.white.opacity(0.15))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("sign.top_candidates", tableName: "Localizable")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: { withAnimation(.easeInOut) { showConfidenceDetails.toggle() } }) {
                            Image(systemName: showConfidenceDetails ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }

                    if showConfidenceDetails {
                        VStack(spacing: 8) {
                            ForEach(cameraManager.topPredictions, id: \.label) { item in
                                HStack {
                                    Text(displaySign(for: item.label))
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(item.label == cameraManager.currentSign
                                                         ? .white : .white.opacity(0.7))
                                    Spacer()
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.white.opacity(0.1)).frame(height: 6)
                                            Capsule()
                                                .fill(item.label == cameraManager.currentSign
                                                      ? Color.cyan : Color.white.opacity(0.4))
                                                .frame(width: geo.size.width * CGFloat(item.confidence), height: 6)
                                        }
                                    }
                                    .frame(width: 100, height: 6)
                                    Text(String(format: "%.0f%%", item.confidence * 100))
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(item.label == cameraManager.currentSign
                                                         ? .cyan : .secondary)
                                        .frame(width: 42, alignment: .trailing)
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 1
                )
        )
    }

    // MARK: - Permission Denied
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            Text("sign.camera_required_title", tableName: "Localizable")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text("sign.camera_required_desc", tableName: "Localizable")
                .font(.system(size: 15)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("sign.open_settings", tableName: "Localizable")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(Capsule().fill(Color.orange))
                    .shadow(color: Color.orange.opacity(0.4), radius: 10, x: 0, y: 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    SignToSpeechView()
}
