//
//  SignToSpeechView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import AVFoundation
import SwiftUI

/// Sign→Speech: camera preview, prediction display, flip camera, speak output.
struct SignToSpeechView: View {
    @Environment(AppStore.self) private var appStore
    @State private var store: SignToSpeechStore?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Camera preview with flip button overlay
                ZStack(alignment: .bottomTrailing) {
                    if store?.isCapturing == true {
                        CameraPreviewView(source: appStore.cameraService)
                            .frame(maxWidth: .infinity)
                            .frame(height: 360)
                            .clipShape(.rect(cornerRadius: 16))
                            .overlay(alignment: .topTrailing) {
                                if appStore.isPredicting {
                                    Image(systemName: "viewfinder")
                                        .font(AppStyle.Font.toolbarIcon)
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

                // Prediction output
                Text(store?.predictedText ?? "No sign detected")
                    .font(AppStyle.Font.emphasizedSectionTitle)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(
                        AppStyle.Color.panelBackground,
                        in: .rect(cornerRadius: 12)
                    )

                Spacer()

                // Action buttons
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
                        .tint(store.isCapturing ? AppStyle.Color.stopAction : nil)
                        .disabled(isBusy)
                        .opacity(isBusy ? 0.6 : 1)

                        if store.isCapturing {
                            Button {
                                store.speakPrediction()
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(AppStyle.Font.sectionTitle)
                                    .frame(width: 52, height: 52)
                            }
                            .buttonStyle(.glassProminent)
                            .disabled(store.predictedText.isEmpty)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Sign to Speech")
            .onAppear { store = SignToSpeechStore(appStore: appStore) }
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

    @ViewBuilder
    private var flipButton: some View {
        let isFront = store?.isFrontCamera ?? true
        Button {
            Task { await store?.flipCamera() }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(AppStyle.Font.actionTitle)
                .padding(10)
                .background(.ultraThinMaterial, in: .circle)
                .clipShape(.circle)
        }
        .buttonStyle(.plain)
        .shadow(color: AppStyle.Color.shadow, radius: 4, y: 2)
        .help(isFront ? "Switch to rear camera" : "Switch to front camera")
    }
}

#Preview {
    SignToSpeechView()
        .environment(AppStore(inferencer: MockSignLanguageInferencer()))
}
