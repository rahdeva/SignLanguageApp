//
//  SignView.swift
//  SignLanguageApp
//
//  Created by Cyintia Limmanto on 22/07/26.
//  Refactored & Logic Connected by Antigravity.
//

import SwiftUI
import SwiftData

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

struct SignView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var recognizer = SignRecognitionEngine(
        stableThreshold: 1,
        cooldownThreshold: 5,
        maxWords: 12
    )
    @State private var speechStore: SpeechToTextStore?
    @State private var showConfidenceDetails = false

    // MARK: - Game State
    @State private var currentChallenge: PracticeChallenge = PracticeChallenge(question: "Apa yang kamu lakukan hari ini?", targetTokens: ["Saya", "Lagi", "Makan"])
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

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    cameraPane
                    playCard
                    startButton
                }
                .padding(.vertical, 16)
            }
            
            // Challenge Generating Overlay
            if isGeneratingChallenge {
                generatingOverlayView
                    .zIndex(11)
            }
        }
        .sheet(isPresented: $showResult) {
            ResultSheet(
                currentChallenge: currentChallenge,
                resultIcon: gameResultLevel.sfSymbol,
                resultColor: gameResultLevel.color,
                resultTitle: gameResultLevel.title,
                resultDesc: gameResultLevel.description,
                completedCount: nextTargetIndex,
                durationSeconds: max(1, 30 - timerSecondsRemaining),
                onPlayAgain: {
                    handleStartGameTap()
                },
                onSaveToHistory: {
                    saveSessionToSwiftData()
                }
            )
            .presentationDetents([.large])
        }
        .onAppear {
            if speechStore == nil {
                speechStore = SpeechToTextStore(appStore: appStore)
            }
            if !isGameActive {
                handleStartGameTap()
            }
        }
        .onDisappear {
            cancelWink()
            stopGameTimer()
            speechStore?.stopRecording()
        }
        .onChange(of: appStore.conversationHistory) { _, history in
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
    
    // MARK: - Camera Pane
    
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
                .frame(height: 280)
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
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }

            if cameraManager.permissionGranted {
                flipButton.padding(12)
            }
        }
        .padding(.horizontal, 16)
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

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text("sign.camera_required_title", tableName: "Localizable")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text("sign.camera_required_desc", tableName: "Localizable")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("sign.open_settings", tableName: "Localizable")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.orange))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
    
    private var cameraResetButton: some View {
        Button {
            resetSignRecognition()
        } label: {
            Label("Reset Sign", systemImage: "arrow.counterclockwise")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: .capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var flipButton: some View {
        Button {
            withAnimation(.spring()) {
                cameraManager.toggleCamera()
            }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                .font(.title3.weight(.semibold))
                .padding(10)
                .background(.ultraThinMaterial, in: .circle)
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }

    // MARK: - Play Card & Tasks
    
    private struct StatusChip: View {
        let text: String
        var isGreen: Bool = true
        var showsCheckmark: Bool = true
        
        var body: some View {
            HStack(spacing: 4) {
                if showsCheckmark {
                    Image(systemName: "checkmark")
                        .foregroundColor(isGreen ? .green : .blue)
                        .font(.caption.bold())
                } else {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
                
                Text(text)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(isGreen ? .green : .blue)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isGreen ? Color.green.opacity(0.15) : Color.blue.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                Group {
                    if !isGreen {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.blue.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    }
                }
            )
        }
    }
    
    private var playCard: some View {
        VStack(spacing: 18) {
            // Caregiver Question Section
            VStack(alignment: .leading, spacing: 10) {
                Text("PERTANYAAN CAREGIVER")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                    
                    HStack(spacing: 12) {
                        Text(currentChallenge.question)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                        
                        Button {
                            toggleSpeechRecording()
                        } label: {
                            Image(systemName: speechStore?.isRecording == true ? "mic.circle.fill" : "mic.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(speechStore?.isRecording == true ? .red : .blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(18)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Target Kalimat Section
            VStack(alignment: .leading, spacing: 6) {
                Text("Target Kalimat")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    ForEach(0..<currentChallenge.targetTokens.count, id: \.self) { idx in
                        let token = currentChallenge.targetTokens[idx]
                        let isCompleted = idx < nextTargetIndex
                        
                        Text(token)
                            .font(.headline.weight(.bold))
                            .foregroundColor(isCompleted ? .green : .secondary)
                            .underline(!isCompleted)
                    }
                }
                
                Text("\(nextTargetIndex) dari \(currentChallenge.targetTokens.count) kata terdeteksi")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Kata Terdeteksi Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Kata Terdeteksi")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Timer capsule
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .foregroundColor(timerColor)
                        Text("\(timerSecondsRemaining)s")
                            .fontWeight(.bold)
                            .foregroundColor(timerColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(timerColor.opacity(0.12))
                    .cornerRadius(12)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<currentChallenge.targetTokens.count, id: \.self) { idx in
                            let token = currentChallenge.targetTokens[idx]
                            let isCompleted = idx < nextTargetIndex
                            
                            StatusChip(
                                text: token,
                                isGreen: isCompleted,
                                showsCheckmark: isCompleted
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(18)
        .background(Color("CardColor"))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
    
    private var startButton: some View {
        Button(action: handleStartGameTap) {
            HStack {
                Image(systemName: "play.fill")
                Text(isGameActive ? "Restart Game" : "Start Game")
            }
            .font(.headline.weight(.bold))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color("TealColor"))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var generatingOverlayView: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.blue)
                    .scaleEffect(1.2)
                
                Text("Memuat Tantangan...")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
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

    // MARK: - Logic & Game Mechanics
    
    private func playImpactHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private func handleStartGameTap() {
        playImpactHaptic()
        stopGameTimer()
        nextTargetIndex = 0
        showResult = false
        isGameActive = true
        timerSecondsRemaining = 30
        cameraManager.resetBuffer()
        recognizer.clearAll()
        appStore.signPredictionOutput = ""
        
        startGameTimer()
        fetchNewChallenge()
    }

    private func startGameTimer() {
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

    private func stopGameTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
    }

    private func endGame(with forcedLevel: GameResultLevel? = nil) {
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

        let generator = UINotificationFeedbackGenerator()
        switch finalLevel {
        case .good: generator.notificationOccurred(.success)
        case .okay: generator.notificationOccurred(.warning)
        case .bad: generator.notificationOccurred(.error)
        }
    }

    private func saveSessionToSwiftData() {
        let duration = max(1, 30 - timerSecondsRemaining)
        let scoreText = gameResultLevel == .good ? "Keren" : (gameResultLevel == .okay ? "Bagus" : "Kurang")
        
        let item = PracticeHistoryItem(
            date: Date(),
            question: currentChallenge.question,
            targetTokens: currentChallenge.targetTokens,
            completedCount: nextTargetIndex,
            durationSeconds: duration,
            scoreRawValue: scoreText
        )
        modelContext.insert(item)
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func fetchNewChallenge() {
        Task {
            isGeneratingChallenge = true
            let challenge = await ChallengeGenerator.generateChallenge(targetLanguage: appStore.languageSettings.ttsLanguage)
            await MainActor.run {
                currentChallenge = challenge
                isGeneratingChallenge = false
            }
        }
    }

    private func handleSpokenQuestion(_ question: String) {
        Task {
            isGeneratingChallenge = true
            let tokens = await ChallengeGenerator.generateTokens(for: question, targetLanguage: appStore.languageSettings.ttsLanguage)
            await MainActor.run {
                currentChallenge = PracticeChallenge(question: question, targetTokens: tokens)
                isGeneratingChallenge = false
                nextTargetIndex = 0
                startGameTimer()
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

    private func resetSignRecognition() {
        withAnimation {
            cameraManager.resetBuffer()
            recognizer.clearAll()
            appStore.signPredictionOutput = ""
        }
    }

    private func handleEyeTrackingUpdate() {
        guard isEyeCloseControlEnabled, isSignActive else { return }
        let leftClosed = cameraManager.isLeftEyeClosed
        let rightClosed = cameraManager.isRightEyeClosed
        let isOneEyeClosed = (leftClosed && !rightClosed) || (!leftClosed && rightClosed)
        
        if isOneEyeClosed {
            if winkStart == nil {
                winkStart = Date()
                winkProgress = 0.01
                startWinkTimer()
            }
        } else {
            cancelWink()
        }
    }

    private func startWinkTimer() {
        winkTimer?.invalidate()
        winkTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                guard let start = self.winkStart else { return }
                let elapsed = Date().timeIntervalSince(start)
                self.winkProgress = min(1.0, elapsed / 1.0)
                if elapsed >= 1.0 {
                    self.cancelWink()
                    self.endGame()
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
}

#Preview {
    SignView()
}
