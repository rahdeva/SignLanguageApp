//
//  SpeechToTextView.swift
//  StellaApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftUI

// MARK: - Palette

/// Design tokens for the Speech-to-Text feature. Native iOS style: calm,
/// high-contrast, blue accent, destructive red.
private enum STT {
    static let background = Color(red: 0.949, green: 0.949, blue: 0.969) // #F2F2F7
    static let accent     = Color(red: 0.173, green: 0.420, blue: 0.929) // #2C6BED
    static let destructive = Color(red: 0.898, green: 0.282, blue: 0.302) // #E5484D
    static let ink        = Color(red: 0.086, green: 0.094, blue: 0.114) // #16181D
    static let secondary  = Color(red: 0.416, green: 0.431, blue: 0.471) // #6A6E78
    static let tileFill   = Color(red: 0.918, green: 0.941, blue: 0.996) // #EAF0FE
    static let partial    = Color(red: 0.604, green: 0.627, blue: 0.675) // #9AA0AC
}

// MARK: - SpeechToTextView

/// Speech→Text: records microphone audio and displays live transcription.
/// Switches between an idle screen and a live listening screen.
struct SpeechToTextView: View {
    @Environment(AppStore.self) private var appStore
    @State private var store: SpeechToTextStore?

    private var isListening: Bool { store?.isRecording ?? false }

    var body: some View {
        ZStack {
            STT.background.ignoresSafeArea()

            if isListening {
                ListeningScreen(
                    transcript: store?.transcribedText ?? "",
                    onStop: { store?.stopRecording() }
                )
                .transition(.opacity)
            } else {
                IdleScreen(onStart: { store?.startRecording() })
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isListening)
        .onAppear { if store == nil { store = SpeechToTextStore(appStore: appStore) } }
        .alert(
            "Error",
            isPresented: Binding(
                get: { appStore.showingError },
                set: { appStore.showingError = $0 }
            )
        ) {
            Button("OK") { appStore.dismissError() }
            Button("Settings") { PermissionService.openSettings() }
        } message: {
            Text(appStore.error?.localizedDescription ?? "")
        }
    }
}

// MARK: - Idle Screen

private struct IdleScreen: View {
    let onStart: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var iconTile: CGFloat = 80

    var body: some View {
        VStack(spacing: 0) {
            // Large title + subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text("speech.title")
                    .font(.largeTitle.bold())
                    .foregroundStyle(STT.ink)
                Text("speech.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(STT.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)

            // Full-height white card
            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(STT.tileFill)
                    .frame(width: iconTile, height: iconTile)
                    .overlay(
                        Image(systemName: "mic.fill")
                            .font(.system(size: iconTile * 0.42, weight: .semibold))
                            .foregroundStyle(STT.accent)
                    )

                Text("speech.ready.heading")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(STT.ink)

                Text("speech.ready.caption")
                    .font(.subheadline)
                    .foregroundStyle(STT.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white)
            )
            .padding(.horizontal, 20)

            // Pinned bottom: primary button + privacy caption
            VStack(spacing: 10) {
                Button(action: onStart) {
                    Label("speech.start", systemImage: "mic.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(STT.accent)
                )
                .shadow(color: STT.accent.opacity(0.30), radius: 12, x: 0, y: 6)

                Text("speech.privacy")
                    .font(.system(size: 13))
                    .foregroundStyle(STT.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Listening Screen

private struct ListeningScreen: View {
    let transcript: String
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("speech.listening.title")
                .font(.largeTitle.bold())
                .foregroundStyle(STT.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            ListeningBadge()

            // Tall transcription card with live text.
            ScrollView {
                transcriptText
                    .font(.system(size: 23, weight: .regular))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white)
            )
            .padding(.horizontal, 20)

            WaveformView()
                .frame(height: 48)
                .padding(.horizontal, 20)

            Button(action: onStop) {
                Label("speech.stop", systemImage: "stop.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 58)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(STT.destructive)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    /// Renders confirmed words in ink and the trailing (still-changing) word in gray.
    private var transcriptText: Text {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Text("speech.listening.placeholder").foregroundColor(STT.partial)
        }

        var words = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard words.count > 1 else {
            return Text(trimmed).foregroundColor(STT.partial)
        }

        let trailing = words.removeLast()
        let confirmed = words.joined(separator: " ")

        var confirmedRun = AttributedString(confirmed + " ")
        confirmedRun.foregroundColor = STT.ink
        var trailingRun = AttributedString(trailing)
        trailingRun.foregroundColor = STT.partial
        return Text(confirmedRun + trailingRun)
    }
}

// MARK: - Listening Badge

private struct ListeningBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(STT.accent)
                .frame(width: 10, height: 10)
                .scaleEffect(pulse ? 1.0 : 0.6)
                .opacity(pulse ? 1.0 : 0.5)
                .animation(
                    reduceMotion
                        ? nil
                        : .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                    value: pulse
                )

            Text("speech.listening.badge")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(STT.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(STT.tileFill))
        .onAppear { if !reduceMotion { pulse = true } }
    }
}

// MARK: - Waveform

/// A row of thin blue bars that animate independently to suggest live audio.
/// Falls back to a static row when Reduce Motion is on.
private struct WaveformView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    private let barCount = 13
    // Deterministic per-bar targets so the motion looks organic but stable.
    private let peaks: [CGFloat] = [0.4, 0.9, 0.55, 1.0, 0.5, 0.75, 0.35, 0.85, 0.6, 1.0, 0.45, 0.8, 0.5]
    private let durations: [Double] = [0.5, 0.7, 0.45, 0.8, 0.55, 0.65, 0.5, 0.75, 0.6, 0.85, 0.5, 0.7, 0.55]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(STT.accent)
                    .frame(width: 4)
                    .scaleEffect(y: barScale(i), anchor: .center)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: durations[i]).repeatForever(autoreverses: true),
                        value: animating
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { if !reduceMotion { animating = true } }
        .accessibilityHidden(true)
    }

    /// Static varied waveform when Reduce Motion is on; animates between a low
    /// baseline and each bar's peak otherwise.
    private func barScale(_ i: Int) -> CGFloat {
        if reduceMotion { return peaks[i] }
        return animating ? peaks[i] : 0.25
    }
}

#Preview("Idle") {
    SpeechToTextView()
        .environment(AppStore())
}
