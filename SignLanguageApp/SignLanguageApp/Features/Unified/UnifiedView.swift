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
                            messageText: "Saya sedang pergi ke rumah ibu yang sedang sakit, maaf terima kasih",
                            isActive: true,
                            accentColor: .blue
                        )
                        SeparatorLine()
                        ConversationComponentView(
                            title: "Speech to Text",
                            subtitle: "Voice input transcribing in real-time",
                            iconName: "mic.fill",
                            senderLabel: "Care Giver Transcribe:",
                            messageText: "Oh begitu, saya paham maksud anda! Dimengerti",
                            isActive: false,
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
