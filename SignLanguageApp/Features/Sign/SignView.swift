//
//  SignView.swift
//  SignLanguageApp
//
//  Created by Cyintia Limmanto on 22/07/26.
//

import SwiftUI

enum GameResultLevel {
    case good
    case okay
    case bad
    
    var title: String {
        switch self {
        case .good: return "GOOD"
        case .okay: return "OKAY"
        case .bad: return "BAD"
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
    
    // MARK: - Game Mechanics
    
    func playImpactHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    func startNewGame() {
        playImpactHaptic()
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
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGray6)
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 10) {
                cameraPane
                playCard
                startButton
            }
            .padding(.vertical, 20)
    
        }
        .sheet(isPresented: $showResult) {
            ResultSheet(
                currentChallenge: currentChallenge,
                resultIcon: gameResultLevel.sfSymbol,
                resultColor: gameResultLevel.color,
                resultTitle: gameResultLevel.title,
                resultDesc: gameResultLevel.description
            )
            .presentationDetents([.large])
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
        .padding(.top, 10)
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

    // A view for the green or blue text "chips" (tags)
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
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(isGreen ? .green : .blue)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isGreen ? Color.green.opacity(0.15) : Color.clear)
            .cornerRadius(12)
            .overlay(
                // Use a dashed overlay for the incomplete chip
                Group {
                    if !isGreen {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    }
                }
            )
        }
    }
    
    private var playCard: some View {
        VStack(spacing: 20) {
            // Caregiver Question Section
            VStack(alignment: .leading, spacing: 10) {
                Text("PERTANYAAN CAREGIVER")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                
                HStack(spacing: 12) {
                    // User icon
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.1, green: 0.15, blue: 0.4))
                            .frame(width: 50, height: 50)
                        Image(systemName: "person.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                    
                    // Question speech bubble
                    HStack(spacing: 12) {
                        Text("Apa yang kamu lakukan hari ini?")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true) // Mencegah teks terpotong jika terlalu panjang
                        
                        Image(systemName: "mic.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    // Menggunakan systemGray6 agar background otomatis berubah gelap di Dark Mode
                    .background(Color(UIColor.systemGray))
                    .cornerRadius(20)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Target Kalimat Section
            VStack(alignment: .leading, spacing: 6) {
                Text("Target Kalimat")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                // Dynamic mixed text dengan Text concatenation
                // Menggabungkan setiap token menjadi satu kesatuan Text
                currentChallenge.targetTokens.enumerated().reduce(Text("")) { (result, item) in
                    let (idx, token) = item
                    let isCompleted = idx < nextTargetIndex
                    let space = Text(idx == currentChallenge.targetTokens.count - 1 ? "" : " ")
                    
                    let styledText = isCompleted
                        ? Text(token).foregroundColor(.green)
                        : Text(token).foregroundColor(.gray).underline()
                    
                    return result + styledText + space
                }
                
                Text("\(nextTargetIndex) dari \(currentChallenge.targetTokens.count) kata terdeteksi")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .fontWeight(.bold)
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
                            .foregroundColor(.blue)
                        Text("\(timerSecondsRemaining)s")
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Dynamic Word chips menggunakan ScrollView agar aman jika jumlah kata banyak
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
        .padding(20)
        .background(Color("CardColor"))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 10)
    }
    
    private var startButton: some View {
        Button(action: startNewGame) {
            HStack {
                Image(systemName: "play.fill")
                Text("Start")
            }
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color("TealColor"))
            .cornerRadius(20)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
}

#Preview {
    SignView()
}
