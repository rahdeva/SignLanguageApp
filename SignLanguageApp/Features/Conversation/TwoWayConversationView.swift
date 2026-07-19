//
//  TwoWayConversationView.swift
//  SignLanguageApp
//
//  Created by rahdeva on 19/07/26.
//  Integrated two-way conversation mode with eye aspect ratio (EAR) controls.
//

import SwiftUI

struct TwoWayConversationView: View {
    @Environment(AppStore.self) private var appStore
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var recognizer = SignRecognitionEngine(
        stableThreshold: 2,
        cooldownThreshold: 5,
        maxWords: 12
    )
    @State private var speechStore: SpeechToTextStore?
    @StateObject private var store: TwoWayConversationStore

    init() {
        let cam = CameraManager()
        let rec = SignRecognitionEngine()
        _cameraManager = StateObject(wrappedValue: cam)
        _recognizer = StateObject(wrappedValue: rec)
        _store = StateObject(
            wrappedValue: TwoWayConversationStore(
                cameraManager: cam,
                recognizer: rec
            )
        )
    }

    var body: some View {
        ZStack {
            // MARK: - Camera Background / Preview
            if cameraManager.permissionGranted {
                GeometryReader { geo in
                    ZStack {
                        CameraPreviewView(
                            session: cameraManager.session,
                            isFrontCamera: cameraManager.isFrontCamera,
                            cameraManager: cameraManager
                        )

                        if store.isSignDetectionActiveForOverlay {
                            HandOverlayView(handPoints: cameraManager.handPoints)
                        }
                    }
                    .rotationEffect(.degrees(90))
                    .frame(width: geo.size.height, height: geo.size.width)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .ignoresSafeArea()
            } else {
                permissionDeniedView
            }

            // MARK: - UI Overlay Layer
            VStack(spacing: 16) {
                topStatusBar
                    .padding(.horizontal)
                    .padding(.top, 12)

                Spacer()

                // Dynamic Panels based on current mode
                VStack(spacing: 16) {
                    if case .signLanguageActive = store.state {
                        signDetectionCard
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if case .speakingTTS = store.state {
                        ttsSpeakingCard
                            .transition(.opacity.combined(with: .scale))
                    } else {
                        speechToTextCard
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    controlsBar
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            let speech = SpeechToTextStore(appStore: appStore)
            self.speechStore = speech
            store.start(appStore: appStore, speechStore: speech)
        }
        .onDisappear {
            store.stop()
            speechStore?.stopRecording()
        }
    }

    // MARK: - Top Status Bar & Eye Tracker Ring
    private var topStatusBar: some View {
        HStack(spacing: 12) {
            // Mode Status Badge
            HStack(spacing: 8) {
                Circle()
                    .fill(statusIndicatorColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: statusIndicatorColor, radius: 6)

                Text(statusBadgeText)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(1.0)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
            )

            Spacer()

            // Eye Tracking Status & Wink Ring
            HStack(spacing: 10) {
                if case let .winkingTrigger(progress) = store.state {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: CGFloat(progress))
                            .stroke(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 22, height: 22)

                    Text(String(format: "%.1fs", progress))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                } else {
                    Image(systemName: eyeStatusIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(cameraManager.isFaceDetected ? .cyan : .secondary)

                    Text(eyeStatusLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(cameraManager.isFaceDetected ? .white : .secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            )
        }
    }

    // MARK: - Partner Speech Card (Speech to Text)
    private var speechToTextCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(
                    LocalizedStringKey("conv.partner_speech"),
                    systemImage: "waveform.circle.fill"
                )
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.cyan)

                Spacer()

                if case .winkingTrigger = store.state {
                    Text("conv.wink_prompt", tableName: "Localizable")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                } else {
                    Text("conv.listening", tableName: "Localizable")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
            }

            ScrollView {
                Text(
                    (speechStore?.transcribedText.isEmpty ?? true)
                        ? "conv.hint_speech".localized(for: appStore.languageSettings.appLanguage)
                        : (speechStore?.transcribedText ?? "")
                )
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor((speechStore?.transcribedText.isEmpty ?? true) ? .secondary : .white)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)

            Divider().background(Color.white.opacity(0.15))

            // Hint footer / manual switch
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(.secondary)
                Text("conv.hint_wink", tableName: "Localizable")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    withAnimation(.spring()) { store.manualSwitchToSign() }
                }) {
                    Text("conv.btn_sign", tableName: "Localizable")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.cyan.opacity(0.3)))
                        .overlay(Capsule().stroke(Color.cyan, lineWidth: 1))
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Sign Detection Card (Sign to Speech)
    private var signDetectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Label(
                    LocalizedStringKey("conv.your_signing"),
                    systemImage: "hand.raised.fill"
                )
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.orange)

                Spacer()

                Text(displaySign(for: cameraManager.currentSign).uppercased())
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(
                        cameraManager.currentSign == "Uncertain"
                            || cameraManager.currentSign == "Detecting..." ? .yellow : .cyan
                    )
            }

            // Word Sequence Chips (removable on tap)
            if !recognizer.wordSequence.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recognizer.wordSequence) { item in
                            Button(action: {
                                withAnimation { recognizer.removeWord(id: item.id) }
                            }) {
                                HStack(spacing: 6) {
                                    Text(item.text)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.cyan.opacity(0.2)))
                                .overlay(Capsule().stroke(Color.cyan, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.white)
                            .accessibilityLabel("Remove \(item.text)")
                        }
                    }
                }
            }

            // Built / Accumulated Sentence
            VStack(alignment: .leading, spacing: 6) {
                Text(
                    recognizer.builtSentence.isEmpty
                        ? recognizer.wordSequence.map(\.text).joined(separator: " ")
                        : recognizer.builtSentence
                )
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            Divider().background(Color.white.opacity(0.15))

            // Hint / manual TTS button
            HStack {
                Image(systemName: "eyes")
                    .foregroundColor(.secondary)
                Text("conv.hint_open_eyes", tableName: "Localizable")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    withAnimation { recognizer.clearAll() }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.orange)
                }
                .padding(.trailing, 8)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - TTS Speaking Card
    private var ttsSpeakingCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 40))
                .foregroundColor(.cyan)
                .symbolEffect(.bounce, options: .repeating)

            Text("conv.speaking", tableName: "Localizable")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)

            Text(store.lastTTSMessage)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.cyan.opacity(0.3), radius: 20, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
                )
        )
    }

    // MARK: - Controls Footer Bar
    private var controlsBar: some View {
        HStack(spacing: 10) {
            // Camera Flip
            Button(action: { cameraManager.toggleCamera() }) {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            }

            Spacer(minLength: 4)

            // Minimalist AI Refinement Chip Toggle
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    store.isAIRefinementEnabled.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(store.isAIRefinementEnabled ? .yellow : .secondary)
                    Text("conv.ai_refinement", tableName: "Localizable")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(store.isAIRefinementEnabled ? .white : .secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Circle()
                        .fill(store.isAIRefinementEnabled ? Color.yellow : Color.secondary.opacity(0.4))
                        .frame(width: 6, height: 6)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(store.isAIRefinementEnabled ? Color.yellow.opacity(0.2) : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(store.isAIRefinementEnabled ? Color.yellow.opacity(0.8) : Color.white.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Minimalist Eye Control Chip Toggle
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    store.isEyeControlledEnabled.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: store.isEyeControlledEnabled ? "eye.tracking" : "eye.slash")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(store.isEyeControlledEnabled ? .cyan : .secondary)
                    Text("conv.eye_control", tableName: "Localizable")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(store.isEyeControlledEnabled ? .white : .secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Circle()
                        .fill(store.isEyeControlledEnabled ? Color.cyan : Color.secondary.opacity(0.4))
                        .frame(width: 6, height: 6)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(store.isEyeControlledEnabled ? Color.cyan.opacity(0.2) : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(store.isEyeControlledEnabled ? Color.cyan.opacity(0.8) : Color.white.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Permission Denied View
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            Text("sign.camera_required_title", tableName: "Localizable")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text("sign.camera_required_desc", tableName: "Localizable")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("sign.open_settings", tableName: "Localizable")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.orange))
                    .shadow(color: Color.orange.opacity(0.4), radius: 10, x: 0, y: 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Helpers
    private var statusBadgeText: LocalizedStringKey {
        switch store.state {
        case .speechToTextActive: return "conv.badge_listening"
        case .winkingTrigger: return "conv.badge_winking"
        case .signLanguageActive: return "conv.badge_signing"
        case .speakingTTS: return "conv.badge_speaking"
        }
    }

    private var statusIndicatorColor: Color {
        switch store.state {
        case .speechToTextActive: return .green
        case .winkingTrigger: return .yellow
        case .signLanguageActive: return .orange
        case .speakingTTS: return .cyan
        }
    }

    private var eyeStatusIcon: String {
        guard cameraManager.isFaceDetected else { return "face.dashed" }
        if cameraManager.isLeftEyeClosed || cameraManager.isRightEyeClosed {
            return "eye.slash.fill"
        }
        return "eyes"
    }

    private var eyeStatusLabel: LocalizedStringKey {
        guard cameraManager.isFaceDetected else { return "conv.face_none" }
        if cameraManager.isLeftEyeClosed && cameraManager.isRightEyeClosed {
            return "conv.eyes_closed"
        } else if cameraManager.isLeftEyeClosed || cameraManager.isRightEyeClosed {
            return "conv.eyes_wink"
        }
        return "conv.eyes_open"
    }

    private func displaySign(for raw: String) -> String {
        if raw == "Detecting..." || raw == "Uncertain" {
            return raw == "Detecting..."
                ? "sign.detecting".localized(for: appStore.languageSettings.appLanguage)
                : "sign.uncertain".localized(for: appStore.languageSettings.appLanguage)
        }
        let cleaned = SignRecognitionEngine.cleanLabel(raw)
        return SignLabelTranslator.translate(
            cleaned,
            to: appStore.languageSettings.ttsLanguage
        )
    }
}
