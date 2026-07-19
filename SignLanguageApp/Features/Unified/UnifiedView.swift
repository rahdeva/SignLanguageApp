//
//  UnifiedView.swift
//  SignLanguageApp
//
//  Created by Dimas Prihady Setyawan on 19/07/26.
//

import SwiftUI

struct UnifiedView: View {
    @Environment(AppStore.self) private var appStore
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var recognizer = SignRecognitionEngine(
        // Default to 2
        stableThreshold: 2,
        cooldownThreshold: 5,
        maxWords: 12
    )
    @State private var speechStore: SpeechToTextStore?
    @State private var lastAutoPlayedTemanTuliText: String?
    @State private var showConfidenceDetails = true

    private var temanTuliText: String {
        recognizer.builtSentence
    }

    private var caregiverTranscribedText: String {
        speechStore?.transcribedText ?? appStore.speechToTextOutput
    }

    private var isSignActive: Bool {
        cameraManager.permissionGranted && cameraManager.isRunning
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    cameraPane
                    signRecognitionControls
                    conversationSection
                }
            }

            bottomControlBar
        }
        .onAppear {
            if speechStore == nil {
                speechStore = SpeechToTextStore(appStore: appStore)
            }
        }
        .onChange(of: cameraManager.currentSign) { _, newSign in
            handleNewSign(newSign, confidence: cameraManager.currentConfidence)
        }
        .task(id: temanTuliText) {
            guard !temanTuliText.isEmpty,
                  temanTuliText != lastAutoPlayedTemanTuliText
            else { return }

            appStore.signPredictionOutput = temanTuliText
            lastAutoPlayedTemanTuliText = temanTuliText
            await speakTemanTuliTranscription()
        }
    }

    private var cameraPane: some View {
        ZStack(alignment: .bottomTrailing) {
            if cameraManager.permissionGranted {
                GeometryReader { geo in
                    ZStack {
                        CameraPreviewView(
                            session: cameraManager.session,
                            isFrontCamera: cameraManager.isFrontCamera,
                            cameraManager: cameraManager
                        )

                        HandOverlayView(handPoints: cameraManager.handPoints)
                    }
                    .rotationEffect(.degrees(90))
                    .frame(width: geo.size.height, height: geo.size.width)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .frame(height: 360)
                .clipped()
                .overlay(alignment: .top) {
                    cameraStatusBar
                        .padding(12)
                }
            } else {
                permissionDeniedView
                    .frame(height: 360)
            }

            if cameraManager.permissionGranted {
                flipButton.padding(12)
            }
        }
    }

    private var cameraStatusBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(cameraManager.bufferCount == 60 ? .green : .orange)
                    .frame(width: 10, height: 10)

                Text("BISINDO AI")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: .capsule)

            Spacer()

            if cameraManager.bufferCount < 60 {
                ProgressView(value: Double(cameraManager.bufferCount), total: 60)
                    .progressViewStyle(.linear)
                    .tint(.cyan)
                    .frame(width: 56)

                Text("\(cameraManager.bufferCount)/60")
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(.cyan)
            } else {
                Text("LIVE")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green, in: .capsule)
            }
        }
    }

    private var signRecognitionControls: some View {
        VStack(spacing: 12) {
//            if !recognizer.wordSequence.isEmpty {
//                wordSequenceRow
//            }
//
//            if !recognizer.builtSentence.isEmpty || recognizer.isBuildingSentence || recognizer.sentenceError != nil {
//                sentencePanel
//            }
//
//            topPredictionSummary
            wordSequenceRow
        }
        .padding(.horizontal)
    }

    private var conversationSection: some View {
        VStack {
            ConversationComponentView(
                title: "Sign to Text",
                subtitle: "Camera input translating in real-time",
                iconName: "hand.raised.fill",
                senderLabel: "Teman Tuli Transcribe:",
                messageText: temanTuliText,
                isActive: isSignActive,
                accentColor: .blue,
                onReadAloud: speakTemanTuliTranscription
            )

            SeparatorLine()

            ConversationComponentView(
                title: "Speech to Text",
                subtitle: "Voice input transcribing in real-time",
                iconName: "mic.fill",
                senderLabel: "Care Giver Transcribe:",
                messageText: caregiverTranscribedText,
                isActive: speechStore?.isRecording ?? false,
                accentColor: .blue
            )
        }
    }

    private var bottomControlBar: some View {
        HStack(spacing: 16) {
            Button {
                cameraManager.resetBuffer()
                recognizer.clearAll()
                appStore.signPredictionOutput = ""
            } label: {
                Label("Reset Sign", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.glass)

            modelButton
            micButton

            Button {
                speakTemanTuliTranscription()
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title2)
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(.glassProminent)
            .disabled(temanTuliText.isEmpty)
        }
    }

    private var modelButton: some View {
        Button {
            withAnimation(.spring()) {
                cameraManager.switchModel(
                    cameraManager.modelMode == .handOnly ? .multiModal : .handOnly
                )
            }
        } label: {
            Image(systemName: cameraManager.modelMode.sfSymbol)
                .font(.title2.weight(.semibold))
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.glassProminent)
        .tint(cameraManager.modelMode == .multiModal ? .cyan : .blue)
        .accessibilityLabel(
            cameraManager.modelMode == .handOnly
                ? "Switch to multi modal model"
                : "Switch to hand only model"
        )
    }

    private var wordSequenceRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "text.word.spacing")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 30, height: 30)
                    .background(.blue.opacity(0.12), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Kata Terdeteksi")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("\(recognizer.wordSequence.count) kata siap disusun")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if recognizer.silenceProgress > 0 {
                    ZStack {
                        Circle()
                            .stroke(.secondary.opacity(0.2), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: CGFloat(recognizer.silenceProgress))
                            .stroke(
                                .cyan,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 22, height: 22)
                    .animation(.linear(duration: 0.05), value: recognizer.silenceProgress)
                }

                Button(role: .destructive) {
                    clearDetectedWords()
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Clear all detected words")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(recognizer.wordSequence.enumerated()), id: \.element.id) { index, word in
                        wordChip(word, index: index)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        )
    }

    private var sentencePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("KALIMAT", systemImage: "text.bubble.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    withAnimation { recognizer.clearAll() }
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Clear sentence")
            }

            if recognizer.isBuildingSentence {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.cyan)
                    Text("Menyusun kalimat...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if !recognizer.builtSentence.isEmpty {
                Text(recognizer.builtSentence)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    recognizer.buildSentence()
                } label: {
                    Label("Ulangi", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.cyan)
            } else if let error = recognizer.sentenceError {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.orange)

                if !recognizer.builtSentence.isEmpty {
                    Text(recognizer.builtSentence)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
    }

    private var topPredictionSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DETECTED BISINDO SIGN")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(cameraManager.currentSign.uppercased())
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(
                            cameraManager.currentSign == "Uncertain" ||
                                cameraManager.currentSign == "Detecting..." ? .yellow : .cyan
                        )
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }

                Spacer()

                confidenceRing
            }

            if !cameraManager.topPredictions.isEmpty {
                Divider()

                HStack {
                    Text("TOP CANDIDATES")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut) {
                            showConfidenceDetails.toggle()
                        }
                    } label: {
                        Image(systemName: showConfidenceDetails ? "chevron.up" : "chevron.down")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(showConfidenceDetails ? "Hide top candidates" : "Show top candidates")
                }

                if showConfidenceDetails {
                    VStack(spacing: 8) {
                        ForEach(cameraManager.topPredictions, id: \.label) { item in
                            predictionRow(item)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
    }

    private var confidenceRing: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.2), lineWidth: 5)
                .frame(width: 58, height: 58)

            Circle()
                .trim(from: 0, to: CGFloat(cameraManager.currentConfidence))
                .stroke(
                    .cyan,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 58, height: 58)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: cameraManager.currentConfidence)

            VStack(spacing: 0) {
                Text("\(Int(cameraManager.currentConfidence * 100))%")
                    .font(.caption.weight(.black))
                Text("CONF")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func predictionRow(_ item: (label: String, confidence: Double)) -> some View {
        HStack {
            Text(SignRecognitionEngine.cleanLabel(item.label))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.label == cameraManager.currentSign ? .primary : .secondary)

            Spacer()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(item.label == cameraManager.currentSign ? .cyan : .secondary.opacity(0.5))
                        .frame(width: geo.size.width * CGFloat(item.confidence), height: 6)
                }
            }
            .frame(width: 100, height: 6)

            Text(String(format: "%.0f%%", item.confidence * 100))
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(item.label == cameraManager.currentSign ? .cyan : .secondary)
                .frame(width: 42, alignment: .trailing)
        }
    }

    private func wordChip(_ word: DetectedWord, index: Int) -> some View {
        Button {
            withAnimation {
                recognizer.removeWord(id: word.id)
            }
        } label: {
            HStack(spacing: 6) {
                Text(word.text)
                    .font(.subheadline.weight(.bold))

                Image(systemName: "xmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background(.quaternary.opacity(0.45), in: .capsule)
        .overlay {
            Capsule()
                .stroke(.secondary.opacity(0.16), lineWidth: 1)
        }
        .accessibilityLabel("Remove \(word.text)")
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView {
            Label("Camera Access Required", systemImage: "camera.fill.badge.ellipsis")
        } description: {
            Text("Allow camera access to detect Bisindo hand signs in real time.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private func handleNewSign(_ sign: String, confidence: Double) {
        guard sign != "Detecting..." else { return }
        Task { @MainActor in
            recognizer.feed(rawLabel: sign, confidence: confidence)
        }
    }

    private func clearDetectedWords() {
        withAnimation {
            recognizer.clearAll()
            appStore.signPredictionOutput = ""
        }
    }

    private func speakTemanTuliTranscription() {
        Task {
            await speakTemanTuliTranscription()
        }
    }

    private func speakTemanTuliTranscription() async {
        await appStore.synthesizerService.speak(temanTuliText)
        appStore.addToHistory(message: temanTuliText, role: .assistantSpoke)
    }

    @ViewBuilder
    private var micButton: some View {
        if let speechStore {
            Button {
                if speechStore.isRecording {
                    speechStore.stopRecording()
                } else {
                    speechStore.startRecording()
                }
            } label: {
                Image(systemName: speechStore.isRecording ? "mic.circle.fill" : "mic.fill")
                    .font(.title2.weight(.semibold))
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(.glassProminent)
            .tint(speechStore.isRecording ? .red : .blue)
            .accessibilityLabel(speechStore.isRecording ? "Turn off microphone" : "Turn on microphone")
        }
    }

    private var flipButton: some View {
        Button {
            withAnimation(.spring()) {
                cameraManager.toggleCamera()
            }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                .font(.title2.weight(.semibold))
                .padding(10)
                .background(.ultraThinMaterial, in: .circle)
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .help(cameraManager.isFrontCamera ? "Switch to rear camera" : "Switch to front camera")
    }
}

#Preview {
    UnifiedView()
        .environment(AppStore())
}
