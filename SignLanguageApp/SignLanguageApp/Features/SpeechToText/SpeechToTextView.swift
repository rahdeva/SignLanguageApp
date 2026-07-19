//
//  SpeechToTextView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftUI

/// Speech→Text: records microphone audio and displays live transcription.
struct SpeechToTextView: View {
    @Environment(AppStore.self) private var appStore
    @State private var store: SpeechToTextStore?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Status icon — animated waveform while recording, muted icon otherwise.
                if appStore.isTranscribing {
                    VStack(spacing: 16) {
                        Image(systemName: "waveform")
                            .font(AppStyle.Font.recordingIcon)
                            .symbolEffect(.bounce, options: .repeating)
                            .foregroundStyle(AppStyle.Color.accent)
                        Text("Listening...")
                            .font(AppStyle.Font.headline)
                            .foregroundStyle(AppStyle.Color.secondaryText)
                    }
                } else {
                    Image(systemName: "mic.slash")
                        .font(AppStyle.Font.idleIcon)
                        .foregroundStyle(AppStyle.Color.tertiaryText)
                }

                // Transcribed text display
                Text(
                    (store?.transcribedText ?? appStore.speechToTextOutput)
                        .isEmpty
                        ? "Tap the microphone to start"
                        : appStore.speechToTextOutput
                )
                .font(AppStyle.Font.sectionTitle)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(
                    AppStyle.Color.panelBackground,
                    in: .rect(cornerRadius: 16)
                )

                Spacer()

                recordButton
            }
            .padding()
            .navigationTitle("Speech to Text")
            .onAppear { store = SpeechToTextStore(appStore: appStore) }
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

    /// Toggle record/stop button with Liquid Glass style.
    @ViewBuilder
    private var recordButton: some View {
        let isRecording = store?.isRecording ?? false
        Button {
            guard let store else { return }
            if store.isRecording {
                store.stopRecording()
            } else {
                store.startRecording()
            }
        } label: {
            Label(
                isRecording ? "Stop Recording" : "Start Recording",
                systemImage: isRecording
                    ? "stop.circle.fill" : "mic.circle.fill"
            )
            .font(AppStyle.Font.actionTitle)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.glass)
        .tint(isRecording ? AppStyle.Color.stopAction : nil)
        .padding(.horizontal)
        .disabled(appStore.error != nil)
    }
}

#Preview {
    SpeechToTextView()
        .environment(AppStore())
}
