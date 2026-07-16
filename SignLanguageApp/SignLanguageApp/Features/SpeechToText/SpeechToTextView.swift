import SwiftUI

struct SpeechToTextView: View {
    @Environment(AppStore.self) private var appStore
    @State private var store: SpeechToTextStore?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                if appStore.isTranscribing {
                    VStack(spacing: 16) {
                        Image(systemName: "waveform")
                            .font(.system(size: 60))
                            .symbolEffect(.bounce, options: .repeating)
                            .foregroundStyle(.tint)
                        Text("Listening...")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "mic.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                }

                Text((store?.transcribedText ?? appStore.speechToTextOutput).isEmpty
                    ? "Tap the microphone to start"
                    : appStore.speechToTextOutput
                )
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 16))

                Spacer()

                Button {
                    guard let store else { return }
                    if store.isRecording {
                        store.stopRecording()
                    } else {
                        store.startRecording()
                    }
                } label: {
                    Label(
                        store?.isRecording == true ? "Stop Recording" : "Start Recording",
                        systemImage: store?.isRecording == true ? "stop.circle.fill" : "mic.circle.fill"
                    )
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(store?.isRecording == true ? Color.red : Color.accentColor, in: .capsule)
                    .foregroundStyle(.white)
                }
                .padding(.horizontal)
                .disabled(appStore.error != nil)
            }
            .padding()
            .navigationTitle("Speech to Text")
            .onAppear { store = SpeechToTextStore(appStore: appStore) }
            .alert("Error", isPresented: Binding(get: { appStore.showingError }, set: { appStore.showingError = $0 })) {
                Button("OK") { appStore.dismissError() }
                Button("Settings") { PermissionService.openSettings() }
            } message: {
                Text(appStore.error?.localizedDescription ?? "")
            }
        }
    }
}

#Preview {
    SpeechToTextView()
        .environment(AppStore())
}
