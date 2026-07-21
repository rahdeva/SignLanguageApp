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
        stableThreshold: 1,
        cooldownThreshold: 5,
        maxWords: 12
    )
    @State private var speechStore: SpeechToTextStore?
    @State private var lastAutoPlayedTemanTuliText: String?
    @State private var showConfidenceDetails = true
    @State private var showNewSessionAlert = false

    private var temanTuliText: String {
        recognizer.builtSentence
    }

    private var caregiverTranscribedText: String {
        speechStore?.transcribedText ?? appStore.speechToTextOutput
    }

    private var isSignActive: Bool {
        cameraManager.permissionGranted && cameraManager.isRunning
    }

    /// Messages from the active session, sorted chronologically.
    private var sessionMessages: [ChatMessage] {
        guard let session = appStore.activeSession else { return [] }
        return session.messages.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    cameraPane
                    signRecognitionControls
                    sessionToolbar
                    conversationSection
                }
            }

            bottomControlsBar
                .padding(.horizontal)
                .padding(.bottom, 8)
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

    // MARK: - Session Toolbar

    private var sessionToolbar: some View {
        HStack {
            if let session = appStore.activeSession {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("session.active")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    Text("\(session.messageCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: .capsule)

                Button(role: .destructive) {
                    appStore.endSession()
                } label: {
                    Text("session.end")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button {
                    if !appStore.signPredictionOutput.isEmpty || !(speechStore?.transcribedText.isEmpty ?? true) {
                        showNewSessionAlert = true
                    } else {
                        appStore.startSession()
                    }
                } label: {
                    Label("session.start", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 20)
        .alert("session.start_new_title", isPresented: $showNewSessionAlert) {
            Button("session.start_new_confirm") {
                appStore.startSession()
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("session.start_new_desc")
        }
    }

    // MARK: - Conversation Section (Bubble Layout)

    private var conversationSection: some View {
        VStack(spacing: 8) {
            if !sessionMessages.isEmpty {
                ForEach(sessionMessages) { message in
                    MessageBubbleView(
                        content: message.content,
                        role: message.role,
                        timestamp: message.createdAt
                    )
                }
            }

            MessageBubbleView(
                content: temanTuliText,
                role: .sign,
                timestamp: .now,
                isPending: isSignActive && !temanTuliText.isEmpty
            )

            if let transcribed = speechStore?.transcribedText, !transcribed.isEmpty {
                let isNewTranscription = !sessionMessages.contains { $0.content == transcribed }
                if isNewTranscription {
                    MessageBubbleView(
                        content: transcribed,
                        role: .speech,
                        timestamp: .now,
                        isPending: speechStore?.isRecording == true
                    )
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Bottom Controls

    private var bottomControlsBar: some View {
        HStack(spacing: 10) {
            if cameraManager.permissionGranted {
                Button(action: { cameraManager.toggleCamera() }) {
                    Image(systemName: "camera.rotate.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }

            Spacer()

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

            Button {
                resetSignRecognition()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: .capsule)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Camera Pane (unchanged)

    private var cameraPane: some View {
        ZStack(alignment: .bottomTrailing) {
            if cameraManager.permissionGranted {
                ZStack {
                    CameraPreviewView(
                        session: cameraManager.session,
                        isFrontCamera: cameraManager.isFrontCamera,
                        cameraManager: cameraManager
                    )

                    HandOverlayView(handPoints: cameraManager.handPoints)
                }
                .frame(height: 360)
                .clipped()
                .overlay(alignment: .top) {
                    cameraStatusBar
                        .padding(12)
                }
                .overlay(alignment: .bottomLeading) {
                    cameraResetButton
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
                    .fill(cameraManager.bufferCount == 60 ? .green : .yellow)
                    .frame(width: 10, height: 10)

                Text("BISINDO")
                    .font(.caption.weight(.semibold))
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
                    .foregroundStyle(.blue)
            } else {
                Text("LIVE")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green, in: .capsule)
            }
        }
    }

    private var signRecognitionControls: some View {
        VStack(spacing: 12) {
            wordSequenceRow
        }
        .padding(.horizontal, 20)
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
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.background)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        )
    }

    private var cameraResetButton: some View {
        Button {
            resetSignRecognition()
        } label: {
            Label("Reset Sign", systemImage: "arrow.counterclockwise")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: .capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityLabel("Reset sign recognition")
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

    // MARK: - Word chip views

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

    // MARK: - Actions

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

    private func resetSignRecognition() {
        withAnimation {
            cameraManager.resetBuffer()
            recognizer.clearAll()
            appStore.signPredictionOutput = ""
        }
    }

    private func toggleSpeechRecording() {
        guard let speechStore else { return }
        if speechStore.isRecording {
            speechStore.stopRecording()
        } else {
            speechStore.startRecording()
        }
    }

    private func speakTemanTuliTranscription() async {
        await appStore.synthesizerService.speak(temanTuliText)
        appStore.addToHistory(message: temanTuliText, role: .sign)
    }
}

#Preview {
    UnifiedView()
        .environment(AppStore())
}
