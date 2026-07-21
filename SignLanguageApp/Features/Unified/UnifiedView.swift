//
//  UnifiedView.swift
//  SignLanguageApp
//
//  Created by Dimas Prihady Setyawan on 19/07/26.
//

import SwiftUI

enum UnifiedMode: Equatable {
    case caregiverTranscribe
    case signMode
}

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
    
    @State private var mode: UnifiedMode = .caregiverTranscribe
    @State private var winkProgress: Double = 0.0
    @State private var winkStart: Date? = nil
    @State private var winkTimer: Timer? = nil

    @AppStorage("isEyeCloseControlEnabled") private var isEyeCloseControlEnabled = false
    @AppStorage("isFoundationModelEnabled") private var isFoundationModelEnabled = true
    @AppStorage("showEyeVisionOverlay") private var showEyeVisionOverlay = false

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
                    
                    if !isEyeCloseControlEnabled {
                        modeSwitchBar
                    }
                    
                    if mode == .signMode {
                        signRecognitionControls
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    conversationSection
                }
            }
        }
        .onAppear {
            recognizer.isAIRefinementEnabled = isFoundationModelEnabled
            if speechStore == nil {
                speechStore = SpeechToTextStore(appStore: appStore)
            }
            if mode == .caregiverTranscribe {
                speechStore?.startRecording()
            }
        }
        .onDisappear {
            cancelWink()
            speechStore?.stopRecording()
        }
        .onChange(of: isFoundationModelEnabled) { _, newValue in
            recognizer.isAIRefinementEnabled = newValue
        }
        .onChange(of: cameraManager.currentSign) { _, newSign in
            handleNewSign(newSign, confidence: cameraManager.currentConfidence)
        }
        .onChange(of: cameraManager.isLeftEyeClosed) { _, _ in
            handleEyeTrackingUpdate()
        }
        .onChange(of: cameraManager.isRightEyeClosed) { _, _ in
            handleEyeTrackingUpdate()
        }
        .onChange(of: temanTuliText) { _, newText in
            appStore.signPredictionOutput = newText
            // Auto TTS when a sentence is built after silence gap or reaching maxWords during sign mode
            if mode == .signMode && !newText.isEmpty {
                Task {
                    await appStore.speak(newText)
                    appStore.addToHistory(message: newText, role: .assistantSpoke)
                }
            }
        }
    }

    private var cameraPane: some View {
        ZStack(alignment: .bottomTrailing) {
            if cameraManager.permissionGranted {
                ZStack {
                    CameraPreviewView(
                        session: cameraManager.session,
                        isFrontCamera: cameraManager.isFrontCamera,
                        cameraManager: cameraManager
                    )

                    if mode == .signMode {
                        HandOverlayView(handPoints: cameraManager.handPoints)
                    }

                    if isEyeCloseControlEnabled && showEyeVisionOverlay && cameraManager.isFaceDetected {
                        EyeOverlayView(
                            leftEyePoints: cameraManager.skeleton.leftEyePoints,
                            rightEyePoints: cameraManager.skeleton.rightEyePoints,
                            isLeftClosed: cameraManager.isLeftEyeClosed,
                            isRightClosed: cameraManager.isRightEyeClosed
                        )
                    }
                }
                .frame(height: 360)
                .clipped()
                .overlay(alignment: .top) {
                    cameraStatusBar
                        .padding(12)
                }
                .overlay(alignment: .bottomLeading) {
                    if mode == .signMode {
                        cameraResetButton
                            .padding(12)
                    }
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

            // Eye detection countdown circle or eye mode active indicator icon
            if winkProgress > 0 {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: CGFloat(winkProgress))
                            .stroke(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 16, height: 16)
                    
                    Text(String(format: "%.1fs", 1.0 - winkProgress))
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(.yellow)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: .capsule)
                .transition(.scale.combined(with: .opacity))
            } else if isEyeCloseControlEnabled {
                // Eye detection mode active indicator badge
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.cyan)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: .capsule)
                .transition(.scale.combined(with: .opacity))
            }
            /* L R open/closed text badges removed per user preference:
            else if cameraManager.isFaceDetectionEnabled && cameraManager.isFaceDetected {
                HStack(spacing: 6) {
                    eyeBadge(label: "L", isClosed: cameraManager.isLeftEyeClosed, ear: cameraManager.leftEAR)
                    eyeBadge(label: "R", isClosed: cameraManager.isRightEyeClosed, ear: cameraManager.rightEAR)
                }
            }
            */

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

    @ViewBuilder
    private func eyeBadge(label: String, isClosed: Bool, ear: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isClosed ? "eye.slash.fill" : "eye.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(isClosed ? .orange : .green)
            
            Text("\(label): \(isClosed ? "PEJAM" : "OPEN") (\(String(format: "%.2f", ear)))")
                .font(.caption2.monospacedDigit().weight(.bold))
                .foregroundStyle(isClosed ? .orange : .white)
        }
        .animation(.easeInOut(duration: 0.15), value: isClosed)
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
        .padding(.horizontal,20)
    }

    private var modeSwitchBar: some View {
        HStack(spacing: 12) {
            // Caregiver Card Selector
            Button {
                if mode == .signMode {
                    switchToCaregiverMode()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        recognizer.clearAll()
                        mode = .caregiverTranscribe
                        speechStore?.startRecording()
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(mode == .caregiverTranscribe ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)
                        Image(systemName: "mic.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mendengarkan Caregiver")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(mode == .caregiverTranscribe ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("Voice input")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(mode == .caregiverTranscribe ? Color.blue.opacity(0.12) : Color(uiColor: .systemBackground))
                        .shadow(color: .black.opacity(mode == .caregiverTranscribe ? 0.1 : 0.04), radius: 6, x: 0, y: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(mode == .caregiverTranscribe ? Color.blue : Color.clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            // Teman Tuli Card Selector
            Button {
                if mode == .caregiverTranscribe {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        speechStore?.stopRecording()
                        recognizer.clearAll()
                        mode = .signMode
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(mode == .signMode ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)
                        Image(systemName: "hand.raised.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Menyuarakan Teman Tuli")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(mode == .signMode ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("Camera input")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(mode == .signMode ? Color.blue.opacity(0.12) : Color(uiColor: .systemBackground))
                        .shadow(color: .black.opacity(mode == .signMode ? 0.1 : 0.04), radius: 6, x: 0, y: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(mode == .signMode ? Color.blue : Color.clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var conversationSection: some View {
        VStack(spacing: 24) {
            if mode == .signMode {
                ConversationComponentView(
                    title: "Menyuarakan Teman Tuli",
                    subtitle: "Camera input translating in real-time",
                    iconName: "hand.raised.fill",
                    senderLabel: "Menyuarakan Teman Tuli:",
                    messageText: temanTuliText,
                    isActive: isSignActive,
                    showHeaderCard: false,
                    accentColor: .blue,
                    onReadAloud: speakTemanTuliTranscription
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                ConversationComponentView(
                    title: "Mendengarkan Caregiver",
                    subtitle: "Voice input transcribing in real-time",
                    iconName: "mic.fill",
                    senderLabel: "Mendengarkan Caregiver:",
                    messageText: caregiverTranscribedText,
                    isActive: speechStore?.isRecording ?? false,
                    showHeaderCard: false,
                    accentColor: .blue,
                    labelActionIconName: speechStore?.isRecording == true ? "mic.circle.fill" : "mic.fill",
                    labelActionAccessibilityLabel: speechStore?.isRecording == true ? "Turn off microphone" : "Turn on microphone",
                    labelActionTint: speechStore?.isRecording == true ? .red : .blue,
                    onLabelAction: toggleSpeechRecording
                )
                .padding(.bottom, 80)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
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

            FlowLayout(spacing: 8) {
                ForEach(Array(recognizer.wordSequence.enumerated()), id: \.element.id) { index, word in
                    wordChip(word, index: index)
                }
            }
            .padding(.vertical, 2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
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

    private func displaySign(for raw: String) -> String {
        if raw == "Detecting..." || raw == "Uncertain" {
            return raw == "Detecting..."
                ? "sign.detecting".localized(for: appStore.languageSettings.appLanguage)
                : "sign.uncertain".localized(for: appStore.languageSettings.appLanguage)
        }
        let cleaned = SignRecognitionEngine.cleanLabel(raw)
        return SignLabelTranslator.translate(cleaned, to: appStore.languageSettings.ttsLanguage)
    }

    private func handleNewSign(_ sign: String, confidence: Double) {
        guard mode == .signMode else { return }
        guard sign != "Detecting...", sign != "Uncertain" else { return }
        let translated = displaySign(for: sign)
        Task { @MainActor in
            recognizer.feed(rawLabel: translated, confidence: confidence)
        }
    }

    private func handleEyeTrackingUpdate() {
        guard isEyeCloseControlEnabled else {
            cancelWink()
            return
        }

        let isLeftClosed = cameraManager.isLeftEyeClosed
        let isRightClosed = cameraManager.isRightEyeClosed
        let isFaceDetected = cameraManager.isFaceDetected

        guard isFaceDetected else { return }

        let eitherClosed = isLeftClosed || isRightClosed
        let bothOpen = !isLeftClosed && !isRightClosed

        if eitherClosed && !bothOpen {
            if winkTimer == nil {
                startWink()
            }
        } else if bothOpen {
            cancelWink()
        }
    }

    private func startWink() {
        winkStart = Date()
        winkProgress = 0.0
        winkTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            Task { @MainActor in
                guard let start = self.winkStart else {
                    self.cancelWink()
                    return
                }
                
                let isLeftClosed = self.cameraManager.isLeftEyeClosed
                let isRightClosed = self.cameraManager.isRightEyeClosed
                let bothOpen = !isLeftClosed && !isRightClosed
                
                if bothOpen {
                    self.cancelWink()
                    return
                }
                
                let elapsed = Date().timeIntervalSince(start)
                let progress = min(elapsed / 1.0, 1.0)
                self.winkProgress = progress
                
                if elapsed >= 1.0 {
                    self.cancelWink()
                    self.toggleMode()
                }
            }
        }
    }

    private func cancelWink() {
        winkTimer?.invalidate()
        winkTimer = nil
        winkStart = nil
        winkProgress = 0.0
    }

    private func toggleMode() {
        if mode == .caregiverTranscribe {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                speechStore?.stopRecording()
                recognizer.clearAll()
                mode = .signMode
            }
        } else {
            switchToCaregiverMode()
        }
    }

    private func switchToCaregiverMode() {
        Task {
            // 1. Obtain text to speak (raw or FM refined based on Foundation Model toggle)
            let sentenceToSpeak: String
            if recognizer.builtSentence.isEmpty {
                sentenceToSpeak = await recognizer.buildSentenceAsync()
            } else {
                sentenceToSpeak = recognizer.builtSentence
            }
            
            // 2. Perform TTS FIRST before changing mode
            if !sentenceToSpeak.isEmpty {
                await appStore.speak(sentenceToSpeak)
                appStore.addToHistory(message: sentenceToSpeak, role: .assistantSpoke)
            }
            
            // 3. AFTER speaking, clear recognizer and switch mode to caregiver transcribe
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    recognizer.clearAll()
                    mode = .caregiverTranscribe
                    speechStore?.startRecording()
                }
            }
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

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxRowHeight: CGFloat = 0
        var maxContainerWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > 0 && currentX + size.width > width {
                currentX = 0
                currentY += maxRowHeight + spacing
                maxRowHeight = 0
            }
            
            currentX += size.width + spacing
            maxRowHeight = max(maxRowHeight, size.height)
            maxContainerWidth = max(maxContainerWidth, currentX)
        }
        
        return CGSize(width: maxContainerWidth, height: currentY + maxRowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxRowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > bounds.minX && currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += maxRowHeight + spacing
                maxRowHeight = 0
            }
            
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            maxRowHeight = max(maxRowHeight, size.height)
        }
    }
}
