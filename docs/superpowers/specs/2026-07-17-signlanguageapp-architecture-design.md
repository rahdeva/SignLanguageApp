# SignLanguageApp — Architecture & Boilerplate Design

**Date:** 2026-07-17
**Status:** Approved
**iOS Target:** 26.5 (Swift 5, SwiftUI, Observation framework)
**Pattern:** Actor-based service layer + `@Observable` stores

---

## 1. Purpose

Bidirectional communication assistant between **sign language** users and **spoken language** users. Two main pipelines:

| Pipeline | Input | Process | Output |
|----------|-------|---------|--------|
| **Speech→Text** | Microphone audio | `AVAudioEngine` → `SFSpeechRecognizer` | Text on screen |
| **Sign→Speech** | Camera video | `AVCaptureSession` → Core ML → Foundation Model refine → `AVSpeechSynthesizer` | Spoken audio |

> This boilerplate covers the **entire architecture, service layer, and scaffolding** — not the ML model training.

---

## 2. Folder Layout

```
SignLanguageApp/SignLanguageApp/
├── App/
│   └── SignLanguageApp.swift             # @main entry
├── Core/
│   ├── Extensions/
│   │   └── AVCaptureDevice+Extensions.swift
│   ├── Logging/
│   │   └── AppLogger.swift               # os.Logger wrapper
│   └── Permissions/
│       └── PermissionService.swift       # Camera + Mic + Speech auth
├── Models/
│   ├── Transcription.swift               # Speech-to-text result model
│   ├── SignPrediction.swift              # ML model output model
│   └── Conversation.swift                # Conversation history
├── Services/
│   ├── CameraService.swift               # actor: AVCaptureSession manager
│   ├── SpeechRecognizerService.swift     # actor: SFSpeechRecognizer
│   ├── SignLanguageInferencer.swift      # actor (protocol): MLModel wrapper
│   └── SpeechSynthesizerService.swift    # actor: AVSpeechSynthesizer
├── Features/
│   ├── Content/
│   │   └── RootView.swift                # TabView + navigation root
│   ├── SpeechToText/
│   │   ├── SpeechToTextStore.swift       # @Observable state
│   │   └── SpeechToTextView.swift        # SwiftUI
│   └── SignToSpeech/
│       ├── SignToSpeechStore.swift       # @Observable state
│       ├── SignToSpeechView.swift        # SwiftUI
│       └── CameraPreviewView.swift       # UIViewRepresentable
└── Resources/
    └── Assets.xcassets/
```

---

## 3. Architecture: Actor Service Layer

Inspired by Apple's AVCam sample (iOS 27+). Every pipeline uses an **actor** to keep AVFoundation/Core ML calls off the main thread.

```
┌──────────────────────────────────────────────────────────────────┐
│                        AppStore (@Observable)                     │
│  speechToTextOutput │ signPredictionOutput │ conversationHistory│
│  isTranscribing     │ isPredicting         │ error               │
└────────┬─────────────────┬──────────────────────┬────────────────┘
         │                 │                      │
    ┌────▼────┐      ┌─────▼──────┐      ┌───────▼──────────┐
    │ Speech  │      │  Camera    │      │ SignLanguage     │
    │ Service │      │  Service   │      │ Inferencer      │
    │ (actor) │      │  (actor)   │      │ (actor + proto) │
    └─────────┘      └─────┬──────┘      └───────┬──────────┘
                           │                      │
                     ┌─────▼──────┐              │
                     │  AVCapture │      ┌───────▼──────────┐
                     │  VideoData │      │  SpeechSynth     │
                     │  Output    │      │  Service (actor) │
                     └────────────┘      └──────────────────┘
```

### 3.1 Service Rules

- **Every service is an `actor`** — no main-thread blocking, no `unowned`, no `DispatchQueue` manual.
- **`SignLanguageInferencer`** also gets a **protocol** (`SignLanguageInferencing`) because teammates may provide different model implementations (local Core ML, remote, mock for testing).
- **`CameraService`**, **`SpeechRecognizerService`**, **`SpeechSynthesizerService`** have single implementations — no protocol (YAGNI per Airbnb style).
- Services expose `async throws` methods and `AsyncStream` / `AsyncThrowingStream` for real-time output.

### 3.2 PermissionService

Centralized, stateless enum with static `async -> Bool` methods:

- `requestCamera() -> Bool` — `AVCaptureDevice.requestAccess(for: .video)`
- `requestMicrophone() -> Bool` — `AVAudioSession.sharedInstance().requestRecordPermission()`
- `requestSpeech() -> Bool` — `SFSpeechRecognizer.requestAuthorization()`

Permissions requested **lazily** — on first feature use, not at app launch.

---

## 4. Data Models

```swift
struct Transcription: Identifiable, Sendable {
    let id: UUID
    let text: String
    let timestamp: Date
    let isFinal: Bool
}

struct SignPrediction: Identifiable, Sendable {
    let id: UUID
    let gestureLabel: String
    let confidence: Float
    let timestamp: Date
    let rawOutput: [String: Float]
}

struct Conversation: Identifiable, Sendable {
    let id: UUID
    let message: String
    let role: ConversationRole   // .userSigned, .userSpoke, .assistantSpoke
    let timestamp: Date
}

enum ConversationRole: String, Sendable {
    case userSigned
    case userSpoke
    case assistantSpoke
}
```

---

## 5. Services — Detailed Contracts

### 5.1 CameraService (actor)

```
- start() async throws -> AsyncStream<CVPixelBuffer>
- stop()
- switchCamera() async throws
```

- Manages `AVCaptureSession` with `AVCaptureVideoDataOutput` (video frames).
- `automaticallyConfiguresOutputBufferDimensions = true` (iOS 17+ best practice).
- `alwaysDiscardsLateVideoFrames = true`.
- Frame stream delivers `CVPixelBuffer` to consumers (ML inference).
- Applies begin/commitConfiguration for atomic changes (per Apple docs).

### 5.2 SpeechRecognizerService (actor)

```
- start(locale: Locale) async throws -> AsyncThrowingStream<String, Error>
- stop()
```

- Bungkus `AVAudioEngine` + `SFSpeechRecognizer`.
- Gunakan `SFSpeechAudioBufferRecognitionRequest` untuk real-time streaming.
- Per-minute limit handling: restart task jika berhenti karena limit.
- `supportsOnDeviceRecognition` fallback.

### 5.3 SignLanguageInferencer (actor + protocol)

```swift
protocol SignLanguageInferencing: Sendable {
    func predict(_ pixelBuffer: CVPixelBuffer) async throws -> SignPrediction
}
```

- `MLModel.load(contentsOf:configuration:)` async.
- Accept `CVPixelBuffer` input, return `SignPrediction`.
- Team bisa buat `LocalSignLanguageInferencer` (Core ML) atau `MockSignLanguageInferencer` (testing).

### 5.4 SpeechSynthesizerService (actor)

```
- speak(_ text: String, voice: AVSpeechSynthesisVoice?) async
- stop()
- isSpeaking: Bool
```

- `AVSpeechSynthesizer` dengan delegate via `AVSpeechSynthesizerDelegate`.
- Utterance queue management.
- `AVAudioSession` configured for playback.

---

## 6. AppStore & State Management

```swift
@MainActor @Observable
final class AppStore {
    // Services (lazy init)
    private(set) var cameraService = CameraService()
    private(set) var speechService = SpeechRecognizerService()
    private(set) var inferencer: SignLanguageInferencing  // injectable
    private(set) var synthesizerService = SpeechSynthesizerService()

    // Pipeline states
    var speechToTextOutput: String = ""
    var isTranscribing: Bool = false
    var isMicAuthorized: Bool = false

    var signPredictionOutput: String = ""
    var isPredicting: Bool = false
    var isCameraAuthorized: Bool = false

    var conversationHistory: [Conversation] = []
    var error: AppError?
}
```

**Error types:**
```swift
enum AppError: LocalizedError {
    case cameraUnavailable
    case micUnavailable
    case speechUnavailable
    case inferenceFailed(Error)
    case permissionDenied(String)
}
```

**Observation pattern for views:**
```swift
struct SpeechToTextView: View {
    @State private var store = AppStore()
    
    var body: some View {
        ...
    }
}
```

Per Airbnb Swift rules: `@State` stores are `private`, other view properties are `internal`.

---

## 7. Navigation

```swift
enum AppTab: String, CaseIterable {
    case speechToText = "Speech"
    case signToSpeech = "Sign"
    case history
}
```

`RootView`:
```swift
struct RootView: View {
    @State private var appStore = AppStore()
    @State private var selectedTab: AppTab = .speechToText

    var body: some View {
        TabView(selection: $selectedTab) {
            SpeechToTextView()
                .tabItem { Label("Speech", systemImage: "mic") }
                .tag(AppTab.speechToText)
            SignToSpeechView()
                .tabItem { Label("Sign", systemImage: "camera") }
                .tag(AppTab.signToSpeech)
            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
                .tag(AppTab.history)
        }
    }
}
```

- Uses `TabView` with `selection` binding (iOS 18+ `Tab` API not yet adopted; `tabItem` suffices).
- Each tab gets its own `NavigationStack`.

---

## 8. Permissions Flow

```
User taps "Start Transcribing"
  → PermissionService.requestMicrophone()
    → if denied: show alert with settings link
    → if granted: PermissionService.requestSpeech()
      → if denied: show alert
      → if both granted: SpeechRecognizerService.start()
```

Error states:
- **Permission denied**: Alert dengan tombol "Open Settings" (via `UIApplication.openSettingsURLString`).
- **Service unavailable**: Graceful message, log via `AppLogger`.
- **Runtime error**: Store `error` property, view show inline error banner.

---

## 9. Error Handling Strategy

| Layer | Strategy |
|-------|----------|
| **Service (actor)** | Throw `AppError` |
| **Store** | `do/catch` → set `self.error` + log via `AppLogger` |
| **View** | `error` binding → `.alert` or banner |

No `print`, no `fatalError` in production paths. `assert` only for developer invariants.

---

## 10. Testing Strategy

| Component | Approach |
|-----------|----------|
| `Services/*` | Actor isolation — test via `await` calls |
| `SignLanguageInferencer` | Protocol → `MockSignLanguageInferencer` |
| `AppStore` | Inject mock services |
| `Features/*/Store` | Pure state testing via Swift Testing |
| `PermissionService` | Mock via `AVCaptureDevice` swizzling (integration test skip) |

- Testing framework: Swift Testing (`#expect`, `@Test`, `try #require`).
- No `guard` in tests.
- Test file for every Store.

---

## 11. File Manifest (18 files total)

| # | File |
|---|------|
| 1 | `App/SignLanguageApp.swift` |
| 2 | `Core/Logging/AppLogger.swift` |
| 3 | `Core/Permissions/PermissionService.swift` |
| 4 | `Core/Extensions/AVCaptureDevice+Extensions.swift` |
| 5 | `Models/Transcription.swift` |
| 6 | `Models/SignPrediction.swift` |
| 7 | `Models/Conversation.swift` |
| 8 | `Services/CameraService.swift` |
| 9 | `Services/SpeechRecognizerService.swift` |
| 10 | `Services/SignLanguageInferencer.swift` |
| 11 | `Services/SpeechSynthesizerService.swift` |
| 12 | `Features/Content/RootView.swift` |
| 13 | `Features/SpeechToText/SpeechToTextStore.swift` |
| 14 | `Features/SpeechToText/SpeechToTextView.swift` |
| 15 | `Features/SignToSpeech/SignToSpeechStore.swift` |
| 16 | `Features/SignToSpeech/SignToSpeechView.swift` |
| 17 | `Features/SignToSpeech/CameraPreviewView.swift` |

---

## 12. Constraints & Non-goals

- ML **model training** is out of scope (teammates handle this).
- Apple Foundation Model integration is stubbed via `SignLanguageInferencer` — the call site is ready.
- No cloud backend / Firebase / persistence layer beyond in-memory conversation log.
- No `unowned`, no `print`, no singletons, no force-unwraps outside of tests.
