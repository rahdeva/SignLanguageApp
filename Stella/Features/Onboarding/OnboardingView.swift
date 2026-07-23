//
//  OnboardingView.swift
//  Stella
//
//  Created by Antigravity on 23/07/26.
//

import SwiftUI

/// Interactive 3-stage onboarding:
/// Stage 1: Guided Practice (3 words with video tutorial)
/// Stage 2: Independent Practice (same 3 words without video tutorial)
/// Stage 3: Onboarding Score & Result Page
struct OnboardingView: View {
    @Binding var isPresented: Bool

    // MARK: - Onboarding Flow State
    enum Phase: Equatable {
        case guided(stepIndex: Int)
        case practice(stepIndex: Int)
        case result(score: Int)
    }

    @State private var phase: Phase = .guided(stepIndex: 0)
    @State private var targetWords: [String] = []
    @State private var practiceScore: Int = 0

    // Camera & Recognition Engine for Onboarding
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var recognizer = SignRecognitionEngine(
        stableThreshold: 1,
        cooldownThreshold: 3,
        maxWords: 1
    )

    @State private var showSuccessOverlay: Bool = false
    @State private var showConfidenceDetails: Bool = false
    @State private var videoPlayerID: UUID = UUID()

    private var currentWord: String {
        guard !targetWords.isEmpty else { return "Saya" }
        switch phase {
        case .guided(let idx):
            return targetWords[min(idx, targetWords.count - 1)]
        case .practice(let idx):
            return targetWords[min(idx, targetWords.count - 1)]
        case .result:
            return ""
        }
    }

    private var currentEnglishWord: String {
        SignLabelTranslator.translate(currentWord, to: .english)
    }

    private var isSignActive: Bool {
        cameraManager.permissionGranted && cameraManager.isRunning
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            switch phase {
            case .guided(let stepIndex):
                wordStepView(
                    isGuided: true,
                    stepIndex: stepIndex
                )
            case .practice(let stepIndex):
                wordStepView(
                    isGuided: false,
                    stepIndex: stepIndex
                )
            case .result(let score):
                scoreResultView(score: score)
            }
        }
        .onAppear {
            initializeOnboardingWords()
            if !cameraManager.isRunning {
                cameraManager.checkPermissions()
            }
        }
        .onChange(of: cameraManager.currentSign) { _, newSign in
            handleDetectedSign(newSign, confidence: cameraManager.currentConfidence)
        }
    }

    // MARK: - Word Step View (Guided & Practice)

    @ViewBuilder
    private func wordStepView(isGuided: Bool, stepIndex: Int) -> some View {
        ZStack {
            VStack(spacing: 0) {
                // Header Progress Bar
                progressHeader(isGuided: isGuided, stepIndex: stepIndex)

                ScrollView {
                    VStack(spacing: 16) {
                        // 1. Video Tutorial Player (ONLY in Guided Phase)
                        if isGuided {
                            SignVideoPlayerView(
                                word: currentWord,
                                englishWord: currentEnglishWord
                            )
                            .id(videoPlayerID)
                            .padding(.horizontal, 16)
                        }

                        // 2. Target Word Card
                        targetWordCard(isGuided: isGuided)

                        // 3. Camera Practice Pane
                        cameraPane
                    }
                    .padding(.vertical, 16)
                }
            }
            .blur(radius: showSuccessOverlay ? 10 : 0)
            .disabled(showSuccessOverlay)

            // Success Detection Modal Overlay
            if showSuccessOverlay {
                successOverlayView(isGuided: isGuided, stepIndex: stepIndex)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                    .zIndex(10)
            }
        }
    }

    // MARK: - Progress Header

    private func progressHeader(isGuided: Bool, stepIndex: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        isGuided ? "onboarding.guided_phase_title" : "onboarding.practice_phase_title",
                        tableName: "Localizable"
                    )
                    .font(.headline.weight(.bold))

                    Text(
                        isGuided ? "onboarding.guided_phase_subtitle" : "onboarding.practice_phase_subtitle",
                        tableName: "Localizable"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Step Counter Badge (e.g. 1/3)
                Text("\(stepIndex + 1)/3")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(isGuided ? .blue : .purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background((isGuided ? Color.blue : Color.purple).opacity(0.12))
                    .clipShape(Capsule())
            }

            // Visual Progress Line
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    let progressFraction = CGFloat(stepIndex + 1) / 3.0
                    Capsule()
                        .fill(isGuided ? Color.blue : Color.purple)
                        .frame(width: geo.size.width * progressFraction, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(Color(uiColor: .systemBackground))
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }

    // MARK: - Target Word Card

    @ViewBuilder
    private func targetWordCard(isGuided: Bool) -> some View {
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

                if case .guided = phase {
                    Button {
                        videoPlayerID = UUID()
                    } label: {
                        Label("word_practice.replay_button", systemImage: "arrow.clockwise.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .buttonBorderShape(.capsule)
                }
            }

            HStack {
                // Live detection indicator
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
                    advanceStep(didSucceed: false)
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

    // MARK: - Camera Pane

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
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // Camera Controls Overlay
                HStack {
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
            }
            .padding(.horizontal, 16)

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

    // MARK: - Success Modal Overlay

    @ViewBuilder
    private func successOverlayView(isGuided: Bool, stepIndex: Int) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 84, height: 84)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 54))
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
                        advanceStep(didSucceed: true)
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

    // MARK: - Stage 3: Score Result Page

    @ViewBuilder
    private func scoreResultView(score: Int) -> some View {
        VStack(spacing: 28) {
            Spacer()

            // Evaluation Icon Badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: score >= 2 ? [.yellow, .orange] : [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)
                    .shadow(color: Color.orange.opacity(0.4), radius: 15, x: 0, y: 8)

                Image(systemName: score == 3 ? "trophy.fill" : (score == 2 ? "star.fill" : "hand.thumbsup.fill"))
                    .font(.system(size: 54))
                    .foregroundColor(.white)
            }

            VStack(spacing: 12) {
                Text(evaluationText(for: score))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text("Skor Latihan: \(score) / 3")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.secondary)

                Text("onboarding.result_subtitle", tableName: "Localizable")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Button to Finish Onboarding & Enter Main Menu
            Button {
                UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                withAnimation {
                    isPresented = false
                }
            } label: {
                Text("onboarding.finish_button", tableName: "Localizable")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .indigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .padding()
    }

    // MARK: - Logic & Helper Methods

    private func initializeOnboardingWords() {
        let available = ChallengeGenerator.availableWords.shuffled()
        if available.count >= 3 {
            targetWords = Array(available.prefix(3))
        } else {
            targetWords = ["Saya", "Makan", "Rumah"]
        }
    }

    private func handleDetectedSign(_ rawSign: String, confidence: Double) {
        guard confidence >= 0.35, !showSuccessOverlay else { return }

        let cleaned = SignRecognitionEngine.cleanLabel(rawSign)
        let targetCleaned = SignRecognitionEngine.cleanLabel(currentWord)

        if cleaned.caseInsensitiveCompare(targetCleaned) == .orderedSame {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showSuccessOverlay = true
            }
        }
    }

    private func advanceStep(didSucceed: Bool) {
        videoPlayerID = UUID()

        switch phase {
        case .guided(let stepIndex):
            if stepIndex < 2 {
                withAnimation {
                    phase = .guided(stepIndex: stepIndex + 1)
                }
            } else {
                // Transition from Guided Phase -> Practice Phase (same 3 words)
                withAnimation {
                    phase = .practice(stepIndex: 0)
                }
            }

        case .practice(let stepIndex):
            if didSucceed {
                practiceScore += 1
            }
            if stepIndex < 2 {
                withAnimation {
                    phase = .practice(stepIndex: stepIndex + 1)
                }
            } else {
                // Transition from Practice Phase -> Result Page
                withAnimation {
                    phase = .result(score: practiceScore)
                }
            }

        case .result:
            break
        }
    }

    private func evaluationText(for score: Int) -> LocalizedStringKey {
        switch score {
        case 3:
            return LocalizedStringKey("onboarding.eval_perfect")
        case 2:
            return LocalizedStringKey("onboarding.eval_good")
        default:
            return LocalizedStringKey("onboarding.eval_keep_trying")
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}

