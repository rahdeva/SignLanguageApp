# StellaApp

**Bidirectional communication assistant** bridging sign language and spoken language users in real time. Built with SwiftUI, AVFoundation, and Core ML for iOS 26.0+.

> **Team:** Dewa Ayam

---

## Architecture

The app follows an **actor-based service layer** pattern (inspired by Apple's AVCam sample), where each hardware pipeline is managed by a dedicated Swift `actor` to keep AVFoundation and Core ML calls off the main thread.

```
┌──────────────────────────────────────────────────────────┐
│                    AppStore (@Observable)                 │
│  speechToTextOutput │ signPredictionOutput │  history    │
│  isTranscribing     │  isPredicting       │  error       │
└────────┬─────────────────┬──────────────────────┬────────┘
         │                 │                      │
    ┌────▼────┐      ┌─────▼──────┐      ┌───────▼──────────┐
    │ Speech  │      │  Camera    │      │ SignLanguage     │
    │ Service │      │  Service   │      │ Inferencer      │
    │ (actor) │      │  (actor)   │      │ (actor + proto) │
    └─────────┘      └─────┬──────┘      └───────┬──────────┘
                     ┌─────▼──────┐      ┌───────▼──────────┐
                     │ AVCapture  │      │ SpeechSynth      │
                     │ VideoData  │      │ Service (actor)  │
                     │ Output     │      └──────────────────┘
                     └────────────┘
```

### Key patterns

| Pattern | Location |
|---------|----------|
| **Actor isolation** | `Services/*Service.swift` — concurrency-safe AVFoundation access |
| **@Observable state** | `AppStore` + `*Store.swift` — reactive UI bindings |
| **Protocol-based injection** | `SignLanguageInferencing` — swap ML implementations without touching consumers |
| **PreviewSource/PreviewTarget** | `CameraPreviewSource.swift` — Apple AVCam pattern, zero coupling between actor and UIView |
| **Lazy permissions** | `PermissionService.swift` — requested on first feature use, not at launch |
| **AsyncStream** | `CameraService` + `SpeechRecognizerService` — real-time buffer delivery without callbacks |

---

## Project structure

```
StellaApp/
├── App/
│   └── StellaApp.swift              # @main entry → RootView
├── Core/
│   ├── Extensions/
│   │   └── AVCaptureDevice+Extensions.swift
│   ├── Logging/
│   │   └── AppLogger.swift                # os.Logger wrapper
│   └── Permissions/
│       └── PermissionService.swift        # Camera + Mic + Speech auth
├── Models/
│   ├── Conversation.swift                 # History entry model
│   ├── SignPrediction.swift               # ML output model
│   └── Transcription.swift               # STT result model
├── Services/
│   ├── CameraPreviewSource.swift          # PreviewSource/PreviewTarget protocols
│   ├── CameraService.swift                # actor — AVCaptureSession manager
│   ├── SignLanguageInferencer.swift       # actor + protocol — Core ML inference
│   ├── SpeechRecognizerService.swift      # actor — SFSpeechRecognizer
│   ├── SpeechSynthesizerService.swift     # actor — AVSpeechSynthesizer
│   └── Pipeline/
│       ├── AppError.swift                 # Unified error types
│       └── AppStore.swift                 # @Observable central state
├── Features/
│   ├── Content/
│   │   └── RootView.swift                 # TabView (Speech / Sign / History / Settings)
│   ├── History/
│   │   └── HistoryView.swift             # Conversation log
│   ├── Onboarding/
│   │   └── OnboardingView.swift          # First-launch introduction
│   ├── Settings/
│   │   ├── AboutTeamView.swift           # Team "Dewa Ayam" with random chicken emojis
│   │   └── SettingsView.swift            # Onboarding toggle, permissions, version
│   ├── SignToSpeech/                     # Camera → ML → TTS pipeline
│   │   ├── CameraPreviewView.swift       # UIViewRepresentable for AVCaptureVideoPreviewLayer
│   │   ├── SignToSpeechStore.swift       # @Observable state
│   │   └── SignToSpeechView.swift        # Camera preview + predict + speak
│   └── SpeechToText/                     # Microphone → STT pipeline
│       ├── SpeechToTextStore.swift       # @Observable state
│       └── SpeechToTextView.swift        # Record button + transcription display
├── Resources/
│   └── Assets.xcassets/
└── .gitignore
```

---

## Features

### 1. Speech to Text

Captures audio via the device microphone and streams real-time transcription using `SFSpeechRecognizer`.

```
Microphone → AVAudioEngine → SFSpeechRecognizer → Text on screen
```

- Partial results update live
- Indonesian and English locale support
- Mic + speech permissions requested on first use

### 2. Sign to Speech

Opens the camera and runs sign-language inference (Core ML stub ready for model integration). The result can be spoken aloud via `AVSpeechSynthesizer`.

```
Camera → AVCaptureVideoDataOutput → [Core ML] → Text → AVSpeechSynthesizer
```

- Front/rear camera toggle
- `AsyncStream<CVPixelBuffer>` for frame delivery
- `SignLanguageInferencing` protocol — swap in your trained model

### 3. Conversation History

Every transcribed or spoken entry is saved in an in-memory timeline.

- Reverse-chronological list
- Role labels (You Signed / You Spoke / Assistant)
- Empty state with `ContentUnavailableView`

### 4. Onboarding & Settings

- 3-page swipeable **onboarding** on first launch (Next → Get Started)
- Replay from **Settings** anytime
- **About Team** with randomised order and random chicken emoji per member

---

## Requirements

- iOS 26.0+
- Xcode 26+
- Swift 5

**Privacy usage descriptions** configured in project (no Info.plist editing needed):

| Key | Purpose |
|-----|---------|
| `NSCameraUsageDescription` | Sign language detection via camera |
| `NSMicrophoneUsageDescription` | Speech capture for transcription |
| `NSSpeechRecognitionUsageDescription` | Speech-to-text conversion |

---

## Getting started

```bash
# Clone the repository
git clone https://github.com/rahdeva/StellaApp.git
cd SignLanguageApp/StellaApp

# Build (Debug, iOS Simulator)
xcodebuild -scheme StellaApp \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build

# Run tests
xcodebuild -scheme StellaApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

> **Note:** Camera features require a physical device; the simulator provides limited camera support.

---

## Code style

This project follows the [Airbnb Swift Style Guide](https://github.com/airbnb/swift) with these conventions:

- `UpperCamelCase` for types, `lowerCamelCase` for everything else
- `@Observable` stores with Airbnb SwiftUI property rules (`@State private`, view properties `internal`)
- Swift Testing (`#expect`, `@Test`, `try #require`)
- `os.Logger` via `AppLogger` — never `print`/`debugPrint`
- No `unowned`, no singletons, no force-unwraps outside of tests

---

## License

© 2026 Dewa Ayam. All rights reserved.
