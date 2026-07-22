//
//  UnifiedView.swift
//  SignLanguageApp
//
//  Created by Dimas Prihady Setyawan on 19/07/26.
//  Refactored by Antigravity to support BISINDO Practice Game Mode with Native Apple Aesthetic.
//

import SwiftUI

enum GameResultLevel {
    case good
    case okay
    case bad
    
    var title: String {
        switch self {
        case .good: return "LUAR BIASA! (GOOD)"
        case .okay: return "CUKUP BAIK (OKAY)"
        case .bad: return "COBA LAGI (BAD)"
        }
    }
    
    var description: String {
        switch self {
        case .good: return "Hebat! Kamu berhasil memeragakan seluruh isyarat dengan tepat dan berurutan!"
        case .okay: return "Bagus! Kamu berhasil memeragakan sebagian isyarat. Tingkatkan lagi kecepatanmu!"
        case .bad: return "Jangan menyerah! Ayo coba lagi untuk melatih gerakan isyarat BISINDO-mu."
        }
    }
    
    var color: Color {
        switch self {
        case .good: return .green
        case .okay: return .orange
        case .bad: return .red
        }
    }
    
    var sfSymbol: String {
        switch self {
        case .good: return "checkmark.seal.fill"
        case .okay: return "exclamationmark.triangle.fill"
        case .bad: return "xmark.circle.fill"
        }
    }
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
    @State private var showConfidenceDetails = false

    // MARK: - Game State
    @State private var currentChallenge: PracticeChallenge = PracticeChallenge(question: "Kamu sedang apa?", targetTokens: ["Saya", "Lagi", "Makan"])
    @State private var nextTargetIndex = 0
    @State private var timerSecondsRemaining = 30
    @State private var isGameActive = false
    @State private var isGeneratingChallenge = false
    @State private var showResult = false
    @State private var gameResultLevel: GameResultLevel = .bad
    @State private var gameTimer: Timer? = nil

    // MARK: - Eye Control Settings
    @AppStorage("isEyeCloseControlEnabled") private var isEyeCloseControlEnabled = false
    @AppStorage("showEyeVisionOverlay") private var showEyeVisionOverlay = false
    @State private var winkProgress: Double = 0.0
    @State private var winkStart: Date? = nil
    @State private var winkTimer: Timer? = nil

    private var isSignActive: Bool {
        cameraManager.permissionGranted && cameraManager.isRunning
    }

    private var practiceSequenceText: String {
        var result = ""
        for idx in 0..<currentChallenge.targetTokens.count {
            let token = currentChallenge.targetTokens[idx]
            if idx > 0 {
                result += "  ➔  "
            }
            if idx < nextTargetIndex {
                result += "✓ \(token)"
            } else if idx == nextTargetIndex {
                result += "▶ [\(token)]"
            } else {
                result += "• \(token)"
            }
        }
        return result
    }

    var body: some View {
        ZStack {
            // Main Content Layout using Original ScrollView and Elements
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        cameraPane
                        duolingoTaskCard
                    }
                    .padding(.vertical, 20)
                }
            }
            .blur(radius: showResult ? 12 : 0)
            .disabled(showResult)
            
            // Result Screen Overlay (Native Apple Aesthetic)
            if showResult {
                resultOverlayView
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                    .zIndex(10)
            }
            
            // Challenge Generating Overlay
            if isGeneratingChallenge {
                generatingOverlayView
                    .zIndex(11)
            }
        }
        .onAppear {
            if speechStore == nil {
                speechStore = SpeechToTextStore(appStore: appStore)
            }
            fetchNewChallengeAndStart()
        }
        .onDisappear {
            cancelWink()
            stopGameTimer()
            speechStore?.stopRecording()
        }
        .onChange(of: appStore.conversationHistory) { _, history in
            // When caregiver speaks a custom question, intercept it to generate custom tokens
            if let lastMessage = history.last, lastMessage.role == .userSpoke {
                handleSpokenQuestion(lastMessage.message)
            }
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
    }

    // MARK: - Original Layout Panes

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

                    if isEyeCloseControlEnabled && showEyeVisionOverlay && cameraManager.isFaceDetected {
                        EyeOverlayView(
                            leftEyePoints: cameraManager.skeleton.leftEyePoints,
                            rightEyePoints: cameraManager.skeleton.rightEyePoints,
                            isLeftClosed: cameraManager.isLeftEyeClosed,
                            isRightClosed: cameraManager.isRightEyeClosed
                        )
                    }
                }
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
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
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }

            if cameraManager.permissionGranted {
                flipButton.padding(12)
            }
        }
        .padding(.horizontal, 20)
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

            // Game countdown timer badge (Native Style)
            if isGameActive {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .foregroundColor(timerColor)
                    Text("\(timerSecondsRemaining)s")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundColor(timerColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: .capsule)
            }

            // Eye Wink status badge
            if winkProgress > 0 {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: CGFloat(winkProgress))
                            .stroke(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 16, height: 16)
                    
                    Text("Eye Close Control...")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.yellow)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: .capsule)
            }
        }
    }

    private var timerColor: Color {
        if timerSecondsRemaining > 15 {
            return .blue
        } else if timerSecondsRemaining > 5 {
            return .orange
        } else {
            return .red
        }
    }

    private var duolingoTaskCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Part 1: Duolingo-style Speech Bubble for Caregiver Question
            HStack(alignment: .top, spacing: 14) {
                // Avatar icon representing caregiver
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                // Speech Bubble
                VStack(alignment: .leading, spacing: 4) {
                    Text("PERTANYAAN CAREGIVER")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                    
                    HStack(alignment: .center, spacing: 12) {
                        Text(currentChallenge.question)
                            .font(.body.weight(.bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Speech Recording Toggle Button
                        Button {
                            toggleSpeechRecording()
                        } label: {
                            Image(systemName: speechStore?.isRecording == true ? "mic.circle.fill" : "mic.fill")
                                .font(.title3.weight(.bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(speechStore?.isRecording == true ? .red : .blue)
                        .accessibilityLabel(speechStore?.isRecording == true ? "Turn off microphone" : "Turn on microphone")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                }
            }
            
            Divider()
            
            // Part 2: Isyarat Untuk Menjawab (Separated Target Badges)
            VStack(alignment: .leading, spacing: 8) {
                Text("ISYARAT UNTUK MENJAWAB (TARGET)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.blue)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<currentChallenge.targetTokens.count, id: \.self) { idx in
                            let token = currentChallenge.targetTokens[idx]
                            let isCompleted = idx < nextTargetIndex
                            let isActive = idx == nextTargetIndex
                            
                            HStack(spacing: 6) {
                                if isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .imageScale(.small)
                                } else if isActive {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundColor(.blue)
                                        .imageScale(.small)
                                }
                                
                                Text(token)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(isCompleted ? .green : (isActive ? .blue : .primary))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isCompleted ? Color.green.opacity(0.1) : (isActive ? Color.blue.opacity(0.12) : Color.primary.opacity(0.06)))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isCompleted ? Color.green.opacity(0.3) : (isActive ? Color.blue.opacity(0.4) : Color.clear), lineWidth: 1.5)
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            
            Divider()
            
            // Part 3: Word Sequence Card (Kata Terdeteksi & Debug Toolbar)
            wordSequenceRow
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        )
        .padding(.horizontal, 20)
    }

    private var debugManualOverrideRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEBUG MANUAL OVERRIDE (TAP UNTUK MENAMBAH)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ChallengeGenerator.availableWords, id: \.self) { word in
                        Button {
                            handleNewSign(word, confidence: 1.0)
                        } label: {
                            Text(word)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.blue.opacity(0.08), in: .capsule)
                                .overlay(
                                    Capsule()
                                        .stroke(.blue.opacity(0.24), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                }
                .padding(.vertical, 2)
            }
        }
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

            Divider()
                .padding(.vertical, 4)
            
            debugManualOverrideRow
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

    // MARK: - Game Mechanics

    func startNewGame() {
        nextTargetIndex = 0
        showResult = false
        isGameActive = true
        startGameTimer()
    }

    func startGameTimer() {
        stopGameTimer()
        timerSecondsRemaining = 30
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if self.timerSecondsRemaining > 0 {
                    self.timerSecondsRemaining -= 1
                } else {
                    self.endGame()
                }
            }
        }
    }

    func stopGameTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
    }

    func endGame(with forcedLevel: GameResultLevel? = nil) {
        stopGameTimer()
        isGameActive = false
        
        let finalLevel: GameResultLevel
        if let forced = forcedLevel {
            finalLevel = forced
        } else {
            if nextTargetIndex == currentChallenge.targetTokens.count {
                finalLevel = .good
            } else if nextTargetIndex > 0 {
                finalLevel = .okay
            } else {
                finalLevel = .bad
            }
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            gameResultLevel = finalLevel
            showResult = true
        }

        // Haptic notification feedback
        let generator = UINotificationFeedbackGenerator()
        switch finalLevel {
        case .good: generator.notificationOccurred(.success)
        case .okay: generator.notificationOccurred(.warning)
        case .bad: generator.notificationOccurred(.error)
        }
    }

    func fetchNewChallengeAndStart() {
        Task {
            isGeneratingChallenge = true
            let challenge = await ChallengeGenerator.generateChallenge(targetLanguage: appStore.languageSettings.ttsLanguage)
            await MainActor.run {
                currentChallenge = challenge
                isGeneratingChallenge = false
                startNewGame()
            }
        }
    }

    func handleSpokenQuestion(_ question: String) {
        Task {
            isGeneratingChallenge = true
            let tokens = await ChallengeGenerator.generateTokens(for: question, targetLanguage: appStore.languageSettings.ttsLanguage)
            await MainActor.run {
                currentChallenge = PracticeChallenge(question: question, targetTokens: tokens)
                isGeneratingChallenge = false
                startNewGame()
            }
        }
    }

    private func handleNewSign(_ sign: String, confidence: Double) {
        guard isGameActive else { return }
        guard sign != "Detecting...", sign != "Uncertain" else { return }
        let cleaned = SignRecognitionEngine.cleanLabel(sign)
        
        guard nextTargetIndex < currentChallenge.targetTokens.count else { return }
        let targetWord = currentChallenge.targetTokens[nextTargetIndex]
        
        if cleaned.lowercased() == targetWord.lowercased() {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                nextTargetIndex += 1
            }
            
            if nextTargetIndex == currentChallenge.targetTokens.count {
                endGame(with: .good)
            }
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

    // MARK: - Native Overlays

    private var resultOverlayView: some View {
        VStack(spacing: 24) {
            Image(systemName: gameResultLevel.sfSymbol)
                .font(.system(size: 64))
                .foregroundColor(gameResultLevel.color)
            
            VStack(spacing: 8) {
                Text(gameResultLevel.title)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
                
                Text(gameResultLevel.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .center, spacing: 4) {
                    Text("\(nextTargetIndex)/\(currentChallenge.targetTokens.count)")
                        .font(.title2.monospacedDigit().weight(.bold))
                        .foregroundColor(.primary)
                    Text("ISYARAT BENAR")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            }
            
            Button {
                fetchNewChallengeAndStart()
            } label: {
                Text("Main Lagi")
                    .font(.body.weight(.bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 36)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    private var generatingOverlayView: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.blue)
                    .scaleEffect(1.2)
                
                Text("Menghasilkan tantangan...")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView {
            Label("Akses Kamera Dibutuhkan", systemImage: "camera.fill.badge.ellipsis")
        } description: {
            Text("Harap berikan izin akses kamera untuk melatih isyarat secara real-time.")
        } actions: {
            Button("Buka Pengaturan") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
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

    // MARK: - Eye Close Tracking logic

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
                    self.triggerWinkAction()
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

    private func triggerWinkAction() {
        if showResult {
            fetchNewChallengeAndStart()
        } else if isGameActive {
            fetchNewChallengeAndStart()
        }
    }
}

#Preview {
    UnifiedView()
        .environment(AppStore())
}

