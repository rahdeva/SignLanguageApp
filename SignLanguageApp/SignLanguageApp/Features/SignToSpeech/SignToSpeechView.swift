import AVFoundation
import SwiftUI

struct SignToSpeechView: View {
    @Environment(AppStore.self) private var appStore
    @State private var store: SignToSpeechStore?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Camera preview area
                ZStack(alignment: .bottomTrailing) {
                    if store?.isCapturing == true {
                        CameraPreviewView(source: appStore.cameraService)
                            .frame(maxWidth: .infinity)
                            .frame(height: 360)
                            .clipShape(.rect(cornerRadius: 16))
                            .overlay(alignment: .topTrailing) {
                                if appStore.isPredicting {
                                    Image(systemName: "viewfinder")
                                        .font(.title3)
                                        .symbolEffect(.pulse)
                                        .padding(8)
                                        .background(.ultraThinMaterial, in: .circle)
                                        .padding(8)
                                }
                            }
                    } else {
                        ContentUnavailableView(
                            "Camera Off",
                            systemImage: "camera.fill",
                            description: Text("Start the camera to begin sign language detection.")
                        )
                        .frame(maxHeight: 360)
                    }

                    // Flip camera button — positioned over bottom-right of preview
                    if store?.isCapturing == true {
                        flipButton
                            .padding(12)
                    }
                }

                // Prediction output
                Text(store?.predictedText ?? "No sign detected")
                    .font(.title2.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 12))

                Spacer()

                // Action buttons
                HStack(spacing: 16) {
                    if let store {
                        Button {
                            if store.isCapturing {
                                store.stopCapture()
                            } else {
                                store.startCapture()
                            }
                        } label: {
                            Label(
                                store.isCapturing ? "Stop Camera" : "Start Camera",
                                systemImage: store.isCapturing ? "stop.circle.fill" : "camera.fill"
                            )
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .buttonStyle(.glass)
                        .tint(store.isCapturing ? .red : nil)

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
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Sign to Speech")
            .onAppear { store = SignToSpeechStore(appStore: appStore) }
            .alert("Error", isPresented: Binding(get: { appStore.showingError }, set: { appStore.showingError = $0 })) {
                Button("OK") { appStore.dismissError() }
                Button("Settings") { PermissionService.openSettings() }
            } message: {
                Text(appStore.error?.localizedDescription ?? "")
            }
        }
    }

    @ViewBuilder
    private var flipButton: some View {
        let isFront = appStore.cameraService.currentPosition == .front
        Button {
            Task { try? await appStore.cameraService.flipCamera() }
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
    SignToSpeechView()
        .environment(AppStore(inferencer: MockSignLanguageInferencer()))
}
