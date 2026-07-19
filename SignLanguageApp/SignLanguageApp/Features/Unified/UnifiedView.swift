//
//  UnifiedView.swift
//  SignLanguageApp
//
//  Created by Dimas Prihady Setyawan on 19/07/26.
//

import SwiftUI

struct UnifiedView: View{
    
    @Environment(AppStore.self) private var appStore
    @State private var store: SignToSpeechStore?
    @State private var speechStore: SpeechToTextStore?
    @State private var hasAutoPlayedTemanTuliText = false

    private let temanTuliText = "Saya sedang pergi ke rumah ibu yang sedang sakit, maaf terima kasih"

    private var caregiverTranscribedText: String {
        speechStore?.transcribedText ?? appStore.speechToTextOutput
    }
    
    var body: some View{
        VStack {
            ScrollView {
                VStack {
                    ZStack(alignment: .bottomTrailing) {
                        if store?.isCapturing == true {
                            CameraPreviewView(source: appStore.cameraService)
                                .frame(maxWidth: .infinity)
                                .frame(height: 360)
//                                .clipShape(.rect(cornerRadius: 16))
                                .overlay(alignment: .topTrailing) {
                                    if appStore.isPredicting {
                                        Image(systemName: "viewfinder")
                                            .font(.title3)
                                            .symbolEffect(.pulse)
                                            .padding(8)
                                            .background(
                                                .ultraThinMaterial,
                                                in: .circle
                                            )
                                            .padding(8)
                                    }
                                }
                        } else {
                            ContentUnavailableView(
                                "Camera Off",
                                systemImage: "camera.fill",
                                description: Text(
                                    "Start the camera to begin sign language detection."
                                )
                            )
                            .frame(maxHeight: 360)
                        }

                        if store?.isCapturing == true {
                            flipButton.padding(12)
                        }
                    }

                    VStack {
                        ConversationComponentView(
                            title: "Sign to Text",
                            subtitle: "Camera input translating in real-time",
                            iconName: "hand.raised.fill",
                            senderLabel: "Teman Tuli Transcribe:",
                            messageText: temanTuliText,
                            isActive: true,
                            accentColor: .blue,
                            onReadAloud: speakTemanTuliTranscription
                        )

                        SeparatorLine()
                        ConversationComponentView(
                            title: "Speech to Text",
                            subtitle: "Voice input transcribing in real-time",
                            iconName: "mic.fill",
                            senderLabel: "Care Giver Transcribe:",
                            messageText: caregiverTranscribedText,
                            isActive: speechStore?.isRecording ?? false,
                            accentColor: .blue
                        )
                    }
                }
            }

            HStack(spacing: 16) {
                if let store {
                    let isBusy = store.isCameraBusy
                    Button {
                        if store.isCapturing {
                            store.stopCapture()
                        } else if !isBusy {
                            store.startCapture()
                        }
                    } label: {
                        Label(
                            isBusy
                                ? "Please wait..."
                                : store.isCapturing
                                    ? "Stop Camera" : "Start Camera",
                            systemImage: store.isCapturing
                                ? "stop.circle.fill" : "camera.fill"
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.glass)
                    .tint(store.isCapturing ? .red : nil)
                    .disabled(isBusy)
                    .opacity(isBusy ? 0.6 : 1)

                    micButton

                    if store.isCapturing {
                        Button {
                            store.speakPrediction()
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.title2)
                                .frame(width: 52, height: 52)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(store.predictedText.isEmpty)
                    }
                }
            }
//            .padding(.horizontal)
        }
        .onAppear {
            store = SignToSpeechStore(appStore: appStore)
            speechStore = SpeechToTextStore(appStore: appStore)
        }
        .task(id: temanTuliText) {
            guard !temanTuliText.isEmpty, !hasAutoPlayedTemanTuliText else { return }
            hasAutoPlayedTemanTuliText = true
            await speakTemanTuliTranscription()
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
    
    @ViewBuilder
    private var flipButton: some View {
        let isFront = store?.isFrontCamera ?? true
        Button {
            Task { await store?.flipCamera() }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title2.weight(.semibold))
                .padding(10)
                .background(.ultraThinMaterial, in: .circle)
                .clipShape(.circle)
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .help(isFront ? "Switch to rear camera" : "Switch to front camera")
    }

}

#Preview {
    UnifiedView()
}
