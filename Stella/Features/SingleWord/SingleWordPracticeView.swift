//
//  SingleWordPracticeView.swift
//  SignLanguageApp
//
//  Created by Antigravity on 23/07/26.
//

import SwiftUI

struct SingleWordPracticeView: View {
    @Environment(AppStore.self) private var appStore
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var recognizer = SignRecognitionEngine(
        stableThreshold: 1,
        cooldownThreshold: 3,
        maxWords: 1
    )
    
    // MARK: - Word Practice State
    @State private var wordIndex: Int = 0
    @State private var score: Int = 0
    @State private var showSuccessOverlay: Bool = false
    @State private var showConfidenceDetails: Bool = false
    @State private var videoPlayerID: UUID = UUID()

    // MARK: - Eye Control Settings
    @AppStorage("isEyeCloseControlEnabled") private var isEyeCloseControlEnabled = false
    @AppStorage("showEyeVisionOverlay") private var showEyeVisionOverlay = false
    @State private var winkProgress: Double = 0.0
    @State private var winkStart: Date? = nil
    @State private var winkTimer: Timer? = nil

    private var availableWords: [String] {
        ChallengeGenerator.availableWords
    }

    private var currentWord: String {
        availableWords[wordIndex % availableWords.count]
    }

    private var currentEnglishWord: String {
        SignLabelTranslator.translate(currentWord, to: .english)
    }

    private var isSignActive: Bool {
        cameraManager.permissionGranted && cameraManager.isRunning
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        headerScoreBar
                        
                        // 1. Video Example Card (Starts every session)
                        SignVideoPlayerView(
                            word: currentWord,
                            englishWord: currentEnglishWord
                        )
                        .id(videoPlayerID)
                        .padding(.horizontal, 16)

                        // 2. Target Word & Action Control Card
                        targetWordCard

                        // 3. Live Camera Practice Pane
                        cameraPane
                    }
                    .padding(.vertical, 16)
                }
            }
            .blur(radius: showSuccessOverlay ? 10 : 0)
            .disabled(showSuccessOverlay)

            // Success Result Celebration Overlay
            if showSuccessOverlay {
                successOverlayView
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                    .zIndex(10)
            }
        }
        .onAppear {
            if !cameraManager.isRunning {
                cameraManager.checkPermissions()
            }
        }
        .onDisappear {
            cancelWink()
        }
        .onChange(of: cameraManager.currentSign) { _, newSign in
            handleDetectedSign(newSign, confidence: cameraManager.currentConfidence)
        }
        .onChange(of: cameraManager.isLeftEyeClosed) { _, _ in
            handleEyeCloseState()
        }
        .onChange(of: cameraManager.isRightEyeClosed) { _, _ in
            handleEyeCloseState()
        }
    }

    // MARK: - Subviews

    private var headerScoreBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("word_practice.title", tableName: "Localizable")
                    .font(.title2.weight(.bold))
                Text("word_practice.subtitle", tableName: "Localizable")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("\(score)")
                    .font(.headline.weight(.black))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.yellow.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
    }

    private var targetWordCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("word_practice.target_label", tableName: "Localizable")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(currentWord)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.primary)

                        if currentEnglishWord != currentWord {
                            Text("(\(currentEnglishWord))")
                                .font(.title3.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Button {
                    replayVideo()
                } label: {
                    Label("word_practice.replay_button", systemImage: "arrow.clockwise.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .buttonBorderShape(.capsule)
            }

            HStack {
                // Current detection feedback pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(cameraManager.currentConfidence >= 0.35 ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)

                    Text("Deteksi: \(cameraManager.currentSign)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    nextWord()
                } label: {
                    HStack(spacing: 4) {
                        Text("word_practice.next_button", tableName: "Localizable")
                        Image(systemName: "forward.fill")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .padding(.horizontal, 16)
    }

    private var cameraPane: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                ZStack {
                    Color.black
                    if isSignActive {
                        CameraPreviewView(
                            session: cameraManager.session,
                            isFrontCamera: cameraManager.isFrontCamera,
                            cameraManager: cameraManager
                        )
                        HandOverlayView(
                            handPoints: cameraManager.handPoints
                        )
                        if isEyeCloseControlEnabled && showEyeVisionOverlay && cameraManager.isFaceDetected {
                            EyeOverlayView(
                                leftEyePoints: cameraManager.skeleton.leftEyePoints,
                                rightEyePoints: cameraManager.skeleton.rightEyePoints,
                                isLeftClosed: cameraManager.isLeftEyeClosed,
                                isRightClosed: cameraManager.isRightEyeClosed
                            )
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("Kamera tidak aktif")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // Bottom Camera Control Bar
                HStack {
                    // Confidence display button
                    Button {
                        withAnimation { showConfidenceDetails.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.fill")
                            Text("\(Int(cameraManager.currentConfidence * 100))%")
                                .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                    }

                    Spacer()

                    // Switch camera front/back
                    Button {
                        cameraManager.toggleCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            .font(.title3)
                            .padding(10)
                            .background(.thinMaterial)
                            .clipShape(Circle())
                    }
                }
                .foregroundColor(.white)
                .padding(12)

                // Wink Switch Progress Bar
                if isEyeCloseControlEnabled && winkProgress > 0 {
                    VStack {
                        Spacer()
                        ProgressView(value: winkProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .tint(.yellow)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 60)
                    }
                }
            }
            .padding(.horizontal, 16)

            // Top candidates details panel (Expandable)
            if showConfidenceDetails && !cameraManager.topPredictions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Top Candidates:")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)

                    ForEach(cameraManager.topPredictions, id: \.label) { item in
                        HStack {
                            Text(SignRecognitionEngine.cleanLabel(item.label))
                                .font(.caption)
                            Spacer()
                            Text("\(Int(item.confidence * 100))%")
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
                .padding(12)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            }
        }
    }

    private var successOverlayView: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 90, height: 90)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                }

                VStack(spacing: 8) {
                    Text("word_practice.success_title", tableName: "Localizable")
                        .font(.title2.weight(.black))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    Text("word_practice.success_desc", tableName: "Localizable")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    withAnimation {
                        showSuccessOverlay = false
                        nextWord()
                    }
                } label: {
                    Text("word_practice.next_button", tableName: "Localizable")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
            }
            .padding(24)
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(radius: 20)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Helper Methods

    private func handleDetectedSign(_ rawSign: String, confidence: Double) {
        guard confidence >= 0.35, !showSuccessOverlay else { return }
        
        let cleaned = SignRecognitionEngine.cleanLabel(rawSign)
        let targetCleaned = SignRecognitionEngine.cleanLabel(currentWord)
        
        if cleaned.caseInsensitiveCompare(targetCleaned) == .orderedSame {
            score += 1
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showSuccessOverlay = true
            }
        }
    }

    private func nextWord() {
        wordIndex += 1
        videoPlayerID = UUID()
    }

    private func replayVideo() {
        videoPlayerID = UUID()
    }

    // MARK: - Eye Control Logic (Wink Switch)
    private func handleEyeCloseState() {
        guard isEyeCloseControlEnabled else { return }

        let isOneEyeClosed = (cameraManager.isLeftEyeClosed && !cameraManager.isRightEyeClosed) ||
                             (!cameraManager.isLeftEyeClosed && cameraManager.isRightEyeClosed)

        if isOneEyeClosed {
            if winkStart == nil {
                winkStart = Date()
                winkTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    guard let start = winkStart else { return }
                    let elapsed = Date().timeIntervalSince(start)
                    winkProgress = min(elapsed / 1.0, 1.0)

                    if elapsed >= 1.0 {
                        cancelWink()
                        nextWord()
                    }
                }
            }
        } else {
            cancelWink()
        }
    }

    private func cancelWink() {
        winkTimer?.invalidate()
        winkTimer = nil
        winkStart = nil
        winkProgress = 0.0
    }
}
