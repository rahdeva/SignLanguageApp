# SignLanguageApp Boilerplate — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement full production-ready boilerplate for SignLanguageApp — actor-based service layer, `@Observable` stores, camera pipeline, speech services, navigation, permissions, error handling.

**Architecture:** Actor-based service layer (AVCam-inspired) + `@Observable AppStore` connecting services to SwiftUI views. `SignLanguageInferencer` gets a protocol for testability; all other services are concrete actors.

**Tech Stack:** Swift 5, SwiftUI, AVFoundation, Speech, Core ML, AVFAudio, Observation framework. iOS 26.0+.

## Global Constraints

- iOS deployment target 26.0.
- No `unowned`, no `print`, no `fatalError` in production paths.
- Airbnb Swift Style: `@State private`, view properties `internal`, `final class`, `static func` over `class func`.
- `os.Logger` via `AppLogger` for all logging.
- `Bundle.main.bundleIdentifier ?? fallback` — never force-unwrap.
- No singletons, no service locators.
- Swift Testing (`#expect`, `@Test`, `try #require`).
- File system sync (`PBXFileSystemSynchronizedRootGroup`) — no pbxproj edits.

---

## File Manifest

| # | Action | Path |
|---|--------|------|
| 1 | Create | `Core/Extensions/AVCaptureDevice+Extensions.swift` |
| 2 | Create | `Models/Transcription.swift` |
| 3 | Create | `Models/SignPrediction.swift` |
| 4 | Create | `Models/Conversation.swift` |
| 5 | Create | `Core/Permissions/PermissionService.swift` |
| 6 | Create | `Services/CameraService.swift` |
| 7 | Create | `Services/SpeechRecognizerService.swift` |
| 8 | Create | `Services/SignLanguageInferencer.swift` |
| 9 | Create | `Services/SpeechSynthesizerService.swift` |
| 10 | Create | `Services/Pipeline/AppError.swift` |
| 11 | Create | `Services/Pipeline/AppStore.swift` |
| 12 | Create | `Features/Content/RootView.swift` |
| 13 | Create | `Features/SpeechToText/SpeechToTextStore.swift` |
| 14 | Create | `Features/SpeechToText/SpeechToTextView.swift` |
| 15 | Create | `Features/SignToSpeech/SignToSpeechStore.swift` |
| 16 | Create | `Features/SignToSpeech/SignToSpeechView.swift` |
| 17 | Create | `Features/SignToSpeech/CameraPreviewView.swift` |
| 18 | Modify | `App/SignLanguageApp.swift` |
| 19 | Delete | `Features/Content/ContentView.swift` |

---

### Task 1: Foundation Extensions & Models

**Files:**
- Create: `Core/Extensions/AVCaptureDevice+Extensions.swift`
- Create: `Models/Transcription.swift`
- Create: `Models/SignPrediction.swift`
- Create: `Models/Conversation.swift`

**Interfaces:**
- Produces: `Transcription` (Identifiable, Sendable), `SignPrediction` (Identifiable, Sendable), `Conversation` (Identifiable, Sendable), `ConversationRole`, `AVCaptureDevice+defaultCamera`

- [ ] **Step 1: Create AVCaptureDevice extension**

```swift
// Core/Extensions/AVCaptureDevice+Extensions.swift
import AVFoundation

extension AVCaptureDevice {
    static var defaultCamera: AVCaptureDevice {
        let device: AVCaptureDevice? = .default(.external, for: .video, position: .unspecified)
            ?? .default(.builtInWideAngleCamera, for: .video, position: .front)
        guard let camera = device else {
            AppLogger.default.error("No camera device found")
            return .default(.builtInWideAngleCamera, for: .video, position: .front)!
        }
        return camera
    }

    static var defaultMicrophone: AVCaptureDevice? {
        .default(for: .audio)
    }
}
```

- [ ] **Step 2: Create Transcription model**

```swift
// Models/Transcription.swift
import Foundation

struct Transcription: Identifiable, Sendable {
    let id: UUID
    let text: String
    let timestamp: Date
    let isFinal: Bool

    init(id: UUID = UUID(), text: String, timestamp: Date = .now, isFinal: Bool = false) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.isFinal = isFinal
    }
}
```

- [ ] **Step 3: Create SignPrediction model**

```swift
// Models/SignPrediction.swift
import Foundation

struct SignPrediction: Identifiable, Sendable {
    let id: UUID
    let gestureLabel: String
    let confidence: Float
    let timestamp: Date
    let rawOutput: [String: Float]

    init(id: UUID = UUID(), gestureLabel: String, confidence: Float, timestamp: Date = .now, rawOutput: [String: Float] = [:]) {
        self.id = id
        self.gestureLabel = gestureLabel
        self.confidence = confidence
        self.timestamp = timestamp
        self.rawOutput = rawOutput
    }
}
```

- [ ] **Step 4: Create Conversation model**

```swift
// Models/Conversation.swift
import Foundation

enum ConversationRole: String, Sendable, Codable {
    case userSigned, userSpoke, assistantSpoke
}

struct Conversation: Identifiable, Sendable {
    let id: UUID
    let message: String
    let role: ConversationRole
    let timestamp: Date

    init(id: UUID = UUID(), message: String, role: ConversationRole, timestamp: Date = .now) {
        self.id = id
        self.message = message
        self.role = role
        self.timestamp = timestamp
    }
}
```

- [ ] **Step 5: Build check**

Run: `cd SignLanguageApp && xcodebuild -scheme SignLanguageApp -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: add foundation models and AVCaptureDevice extensions"
```

---

### Task 2: PermissionService

**Files:**
- Create: `Core/Permissions/PermissionService.swift`

**Interfaces:**
- Produces: `PermissionService.requestCamera() async -> Bool`, `requestMicrophone() async -> Bool`, `requestSpeech() async -> Bool`

- [ ] **Step 1: Create PermissionService**

```swift
// Core/Permissions/PermissionService.swift
import AVFoundation
import OSLog
import Speech
import UIKit

enum PermissionService {
    static func requestCamera() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status != .denied, status != .restricted else {
            AppLogger.default.warning("Camera permission denied or restricted")
            return false
        }
        guard status == .notDetermined else { return true }
        return await AVCaptureDevice.requestAccess(for: .video)
    }

    static func requestMicrophone() async -> Bool {
        let session = AVAudioSession.sharedInstance()
        let status = session.recordPermission
        guard status != .denied else {
            AppLogger.default.warning("Microphone permission denied")
            return false
        }
        guard status == .undetermined else { return true }
        return await withCheckedContinuation { continuation in
            session.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    static func requestSpeech() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status != .denied, status != .restricted else {
            AppLogger.default.warning("Speech recognition permission denied or restricted")
            return false
        }
        guard status == .notDetermined else { return true }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                continuation.resume(returning: authStatus == .authorized)
            }
        }
    }

    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        Task { @MainActor in
            await UIApplication.shared.open(url)
        }
    }
}
```

- [ ] **Step 2: Build check**

Run: `cd SignLanguageApp && xcodebuild … build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add PermissionService for camera, mic, speech"
```

---

### Task 3: CameraService (actor) + Preview Protocols

**Files:**
- Create: `Services/CameraPreviewSource.swift`
- Create: `Services/CameraService.swift`

**Interfaces:**
- Produces: `PreviewSource` protocol, `PreviewTarget` protocol, `CameraService` actor

- [ ] **Step 1: Create PreviewSource & PreviewTarget protocols**

```swift
// Services/CameraPreviewSource.swift
import AVFoundation

// MARK: - Preview protocols (Apple AVCam pattern)

protocol PreviewSource: AnyObject {
    func connect(to target: any PreviewTarget)
}

protocol PreviewTarget: AnyObject {
    func setSession(_ session: AVCaptureSession)
}
```

- [ ] **Step 2: Create CameraPreviewUIView**

```swift
// Services/CameraPreviewUIView.swift
import AVFoundation
import UIKit

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

extension CameraPreviewUIView: PreviewTarget {
    func setSession(_ session: AVCaptureSession) {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }
}
```

- [ ] **Step 3: Create CameraService actor**

```swift
// Services/CameraService.swift  
import AVFoundation

enum CameraError: LocalizedError {
    case addInputFailed
    case addOutputFailed
    case noCameraAvailable
    case noMicAvailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .addInputFailed: "Failed to add camera input"
        case .addOutputFailed: "Failed to add video output"
        case .noCameraAvailable: "No camera available on this device"
        case .noMicAvailable: "No microphone available on this device"
        case .notAuthorized: "Camera access not authorized"
        }
    }
}

actor CameraService: PreviewSource {
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var activeVideoInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var continuation: AsyncStream<CVPixelBuffer>.Continuation?
    private weak var previewTarget: (any PreviewTarget)?

    nonisolated let pixelBufferStream: AsyncStream<CVPixelBuffer>

    init() {
        var cont: AsyncStream<CVPixelBuffer>.Continuation?
        pixelBufferStream = AsyncStream { continuation in
            cont = continuation
        }
        self.continuation = cont
    }

    nonisolated func connect(to target: any PreviewTarget) {
        Task { await connectOnActor(target) }
    }

    private func connectOnActor(_ target: any PreviewTarget) {
        previewTarget = target
        target.setSession(captureSession)
    }

    func start() async throws {
        guard await PermissionService.requestCamera() else { throw CameraError.notAuthorized }
        if !isConfigured { try configureSession() }
        if !captureSession.isRunning {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    captureSession.startRunning()
                    continuation.resume()
                }
            }
        }
    }

    func stop() {
        guard captureSession.isRunning else { return }
        DispatchQueue.global(qos: .background).async { [self] in
            captureSession.stopRunning()
        }
        continuation?.finish()
    }

    func switchCamera() async throws {
        guard let currentInput = activeVideoInput else { return }
        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .front ? .back : .front
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else { return }
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        captureSession.removeInput(currentInput)
        do {
            activeVideoInput = try addInput(for: newDevice)
        } catch {
            captureSession.addInput(currentInput)
            throw error
        }
    }

    // MARK: - Private

    private func configureSession() throws {
        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
            isConfigured = true
        }
        captureSession.sessionPreset = .high

        let camera = AVCaptureDevice.defaultCamera
        activeVideoInput = try addInput(for: camera)

        if let mic = AVCaptureDevice.defaultMicrophone {
            _ = try? addInput(for: mic)
        }

        videoOutput.setSampleBufferDelegate(
            CameraOutputDelegate(continuation: continuation),
            queue: .init(label: "camera.video.queue", qos: .userInitiated)
        )
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.automaticallyConfiguresOutputBufferDimensions = true

        guard captureSession.canAddOutput(videoOutput) else { throw CameraError.addOutputFailed }
        captureSession.addOutput(videoOutput)
    }

    @discardableResult
    private func addInput(for device: AVCaptureDevice) throws -> AVCaptureDeviceInput {
        let input = try AVCaptureDeviceInput(device: device)
        guard captureSession.canAddInput(input) else { throw CameraError.addInputFailed }
        captureSession.addInput(input)
        return input
    }
}

// MARK: - Sample Buffer Delegate

private final class CameraOutputDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let continuation: AsyncStream<CVPixelBuffer>.Continuation?

    init(continuation: AsyncStream<CVPixelBuffer>.Continuation?) {
        self.continuation = continuation
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        continuation?.yield(pixelBuffer)
    }
}
```

- [ ] **Step 2: Build check**

Run: build
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add CameraService actor with AVCaptureSession"
```

---

### Task 4: SpeechRecognizerService (actor)

**Files:**
- Create: `Services/SpeechRecognizerService.swift`

**Interfaces:**
- Produces: `SpeechRecognizerService` actor — `start(locale:) async throws -> AsyncThrowingStream<String, Error>`, `stop()`

- [ ] **Step 1: Create SpeechRecognizerService actor**

```swift
// Services/SpeechRecognizerService.swift
import AVFoundation
import Speech

enum SpeechError: LocalizedError {
    case unavailable
    case notAuthorized
    case recognitionFailed(Error)
    case noAudioInput

    var errorDescription: String? {
        switch self {
        case .unavailable: "Speech recognition is unavailable"
        case .notAuthorized: "Speech recognition not authorized"
        case .recognitionFailed(let error): "Recognition failed: \(error.localizedDescription)"
        case .noAudioInput: "No audio input available"
        }
    }
}

actor SpeechRecognizerService {
    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    func start(locale: Locale = .current) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard await PermissionService.requestMicrophone() else { throw SpeechError.notAuthorized }
                    guard await PermissionService.requestSpeech() else { throw SpeechError.notAuthorized }

                    let recognizer = SFSpeechRecognizer(locale: locale)
                    guard let recognizer, recognizer.isAvailable else { throw SpeechError.unavailable }
                    self.recognizer = recognizer

                    let audioSession = AVAudioSession.sharedInstance()
                    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                    try audioSession.setActive(true)

                    let inputNode = audioEngine.inputNode
                    let recordingFormat = inputNode.outputFormat(forBus: 0)
                    guard recordingFormat.sampleRate > 0 else { throw SpeechError.noAudioInput }

                    let request = SFSpeechAudioBufferRecognitionRequest()
                    request.shouldReportPartialResults = true

                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                        request.append(buffer)
                    }

                    audioEngine.prepare()
                    try audioEngine.start()

                    recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                        if let error {
                            continuation.finish(throwing: SpeechError.recognitionFailed(error))
                            return
                        }
                        if let result {
                            continuation.yield(result.bestTranscription.formattedString)
                        }
                    }

                    continuation.onTermination = { [weak self] _ in
                        Task { [weak self] in
                            await self?.cleanup()
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func stop() {
        cleanup()
    }

    private func cleanup() {
        recognitionTask?.cancel()
        recognitionTask = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
```

- [ ] **Step 2: Build check**
- [ ] **Step 3: Commit**

---

### Task 5: SignLanguageInferencer (actor + protocol)

**Files:**
- Create: `Services/SignLanguageInferencer.swift`

**Interfaces:**
- Produces: `SignLanguageInferencing` protocol, `SignLanguageInferencer` actor (stub), `MockSignLanguageInferencer`

- [ ] **Step 1: Create protocol + stub + mock**

```swift
// Services/SignLanguageInferencer.swift
import CoreImage
import CoreML

enum InferenceError: LocalizedError {
    case modelNotFound
    case modelLoadFailed(Error)
    case predictionFailed(Error)
    case invalidInput

    var errorDescription: String? {
        switch self {
        case .modelNotFound: "Core ML model not found in bundle"
        case .modelLoadFailed(let error): "Model load failed: \(error.localizedDescription)"
        case .predictionFailed(let error): "Prediction failed: \(error.localizedDescription)"
        case .invalidInput: "Invalid input buffer"
        }
    }
}

protocol SignLanguageInferencing: AnyActor, Sendable {
    func predict(_ pixelBuffer: CVPixelBuffer) async throws -> SignPrediction
}

actor SignLanguageInferencer: SignLanguageInferencing {
    private var model: MLModel?

    init() {}

    func loadModel(named name: String = "SignLanguageModel") async throws {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: name, withExtension: "mlmodel")
        else { throw InferenceError.modelNotFound }

        let config = MLModelConfiguration()
        config.computeUnits = .all
        do {
            model = try await MLModel.load(contentsOf: url, configuration: config)
        } catch {
            throw InferenceError.modelLoadFailed(error)
        }
    }

    func predict(_ pixelBuffer: CVPixelBuffer) async throws -> SignPrediction {
        guard let model else { throw InferenceError.modelNotFound }

        let input: MLFeatureProvider
        do {
            let value = MLFeatureValue(pixelBuffer: pixelBuffer)
            input try MLDictionaryFeatureProvider(dictionary: ["image": value])
        } catch {
            throw InferenceError.invalidInput
        }

        let output: MLFeatureProvider
        do {
            output = try await model.prediction(from: input)
        } catch {
            throw InferenceError.predictionFailed(error)
        }

        let label = output.featureValue(for: "label")?.stringValue ?? "unknown"
        let confidence = output.featureValue(for: "confidence")?.multiArrayValue?[0].floatValue ?? 0

        var rawOutput: [String: Float] = [:]
        if let labelProbabilities = output.featureValue(for: "labelProbability")?.dictionaryValue as? [String: Float] {
            rawOutput = labelProbabilities
        }

        return SignPrediction(gestureLabel: label, confidence: confidence, rawOutput: rawOutput)
    }
}

// MARK: - Mock for testing

actor MockSignLanguageInferencer: SignLanguageInferencing {
    private let stubLabel: String
    private let stubConfidence: Float

    init(stubLabel: String = "hello", stubConfidence: Float = 0.95) {
        self.stubLabel = stubLabel
        self.stubConfidence = stubConfidence
    }

    func predict(_ pixelBuffer: CVPixelBuffer) async throws -> SignPrediction {
        try await Task.sleep(for: .milliseconds(300))
        return SignPrediction(
            gestureLabel: stubLabel,
            confidence: stubConfidence,
            rawOutput: [stubLabel: stubConfidence, "thanks": 0.03, "please": 0.02]
        )
    }
}
```

- [ ] **Step 2: Build check**
- [ ] **Step 3: Commit**

---

### Task 6: SpeechSynthesizerService (actor)

**Files:**
- Create: `Services/SpeechSynthesizerService.swift`

**Interfaces:**
- Produces: `SpeechSynthesizerService` actor — `speak(_:voice:) async`, `stop()`, `isSpeaking`

- [ ] **Step 1: Create SpeechSynthesizerService actor**

```swift
// Services/SpeechSynthesizerService.swift
import AVFAudio

actor SpeechSynthesizerService {
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var isSpeaking = false
    private var continuation: CheckedContinuation<Void, Never>?

    nonisolated init() {}

    func speak(_ text: String, voice: AVSpeechSynthesisVoice? = nil) async {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice ?? .init(language: "id-ID") ?? .init(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        isSpeaking = true

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        await withCheckedContinuation { [self] continuation in
            self.continuation = continuation
            synthesizer.delegate = self
            synthesizer.speak(utterance)
        }
        isSpeaking = false
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        continuation?.resume()
        continuation = nil
    }
}

extension SpeechSynthesizerService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { await resume() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { await resume() }
    }

    private func resume() {
        continuation?.resume()
        continuation = nil
    }
}
```

- [ ] **Step 2: Build check**
- [ ] **Step 3: Commit**

---

### Task 7: AppError + AppStore

**Files:**
- Create: `Services/Pipeline/AppError.swift`
- Create: `Services/Pipeline/AppStore.swift`

**Interfaces:**
- Produces: `AppError` enum, `AppStore` @Observable class

- [ ] **Step 1: Create AppError**

```swift
// Services/Pipeline/AppError.swift
import Foundation

enum AppError: LocalizedError, Equatable {
    case cameraUnavailable
    case micUnavailable
    case speechUnavailable
    case inferenceFailed(String)
    case permissionDenied(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable: "Camera is not available"
        case .micUnavailable: "Microphone is not available"
        case .speechUnavailable: "Speech recognition is not available"
        case .inferenceFailed(let detail): "Sign language recognition failed: \(detail)"
        case .permissionDenied(let feature): "Permission denied for \(feature)"
        case .unknown(let detail): "An error occurred: \(detail)"
        }
    }
}
```

- [ ] **Step 2: Create AppStore**

```swift
// Services/Pipeline/AppStore.swift
import Observation

@MainActor
@Observable
final class AppStore {
    // MARK: - Services
    private(set) var cameraService = CameraService()
    private(set) var speechService = SpeechRecognizerService()
    private(set) var synthesizerService = SpeechSynthesizerService()
    private(set) var inferencer: SignLanguageInferencing

    // MARK: - Speech-to-Text State
    var speechToTextOutput: String = ""
    var isTranscribing = false
    var isMicAuthorized = false

    // MARK: - Sign-to-Speech State
    var signPredictionOutput: String = ""
    var isPredicting = false
    var isCameraAuthorized = false

    // MARK: - Conversation
    var conversationHistory: [Conversation] = []

    // MARK: - Error
    var error: AppError?
    var showingError = false

    // MARK: - Init
    init(inferencer: SignLanguageInferencing = SignLanguageInferencer()) {
        self.inferencer = inferencer
    }

    // MARK: - Actions
    func checkPermissions() async {
        isCameraAuthorized = await PermissionService.requestCamera()
        isMicAuthorized = await PermissionService.requestMicrophone()
        if isMicAuthorized {
            _ = await PermissionService.requestSpeech()
        }
    }

    func dismissError() {
        error = nil
        showingError = false
    }

    func addToHistory(message: String, role: ConversationRole) {
        conversationHistory.append(Conversation(message: message, role: role))
    }
}
```

- [ ] **Step 3: Build check**
- [ ] **Step 4: Commit**

---

### Task 8: RootView (Tab Navigation)

**Files:**
- Create: `Features/Content/RootView.swift`
- Modify: `App/SignLanguageApp.swift`

**Interfaces:**
- Consumes: `AppStore`, `SpeechToTextView`, `SignToSpeechView`
- Produces: `RootView` with TabView and 3 tabs

- [ ] **Step 1: Create RootView**

```swift
// Features/Content/RootView.swift
import SwiftUI

enum AppTab: String, CaseIterable {
    case speechToText = "Speech"
    case signToSpeech = "Sign"
    case history

    var title: String {
        switch self {
        case .speechToText: "Speech to Text"
        case .signToSpeech: "Sign to Speech"
        case .history: "History"
        }
    }

    var icon: String {
        switch self {
        case .speechToText: "mic"
        case .signToSpeech: "camera"
        case .history: "clock"
        }
    }
}

struct RootView: View {
    @State private var appStore = AppStore()
    @State private var selectedTab: AppTab = .speechToText

    var body: some View {
        TabView(selection: $selectedTab) {
            SpeechToTextView()
                .tabItem { Label(AppTab.speechToText.title, systemImage: AppTab.speechToText.icon) }
                .tag(AppTab.speechToText)

            SignToSpeechView()
                .tabItem { Label(AppTab.signToSpeech.title, systemImage: AppTab.signToSpeech.icon) }
                .tag(AppTab.signToSpeech)

            HistoryView()
                .tabItem { Label(AppTab.history.title, systemImage: AppTab.history.icon) }
                .tag(AppTab.history)
        }
        .environment(appStore)
        .task { await appStore.checkPermissions() }
    }
}

// MARK: - History Tab (inline — small enough)

private struct HistoryView: View {
    @Environment(AppStore.self) private var appStore

    var body: some View {
        NavigationStack {
            Group {
                if appStore.conversationHistory.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Start transcribing or signing to build your conversation history.")
                    )
                } else {
                    List(appStore.conversationHistory.reversed()) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.role.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tint)
                                Spacer()
                                Text(entry.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.message)
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
        }
    }
}

private extension ConversationRole {
    var label: String {
        switch self {
        case .userSigned: "You (Sign)"
        case .userSpoke: "You (Speech)"
        case .assistantSpoke: "Assistant"
        }
    }
}
```

- [ ] **Step 2: Update @main entry (App/SignLanguageApp.swift)**

```swift
// App/SignLanguageApp.swift
import SwiftUI

@main
struct SignLanguageApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

- [ ] **Step 3: Delete old ContentView**

```bash
rm Features/Content/ContentView.swift
```

- [ ] **Step 4: Build check**
- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add RootView with tab navigation and history"
```

---

### Task 9: SpeechToText Feature

**Files:**
- Create: `Features/SpeechToText/SpeechToTextStore.swift`
- Create: `Features/SpeechToText/SpeechToTextView.swift`

**Interfaces:**
- Consumes: `AppStore`, `SpeechRecognizerService`, `PermissionService`
- Produces: `SpeechToTextStore` @Observable, `SpeechToTextView`

- [ ] **Step 1: Create SpeechToTextStore**

```swift
// Features/SpeechToText/SpeechToTextStore.swift
import Observation

@MainActor
@Observable
final class SpeechToTextStore {
    private let appStore: AppStore

    var transcribedText: String = ""
    var isRecording = false
    var isAuthorized = false

    init(appStore: AppStore) {
        self.appStore = appStore
    }

    func startRecording() {
        guard !isRecording else { return }
        Task {
            do {
                isAuthorized = await PermissionService.requestMicrophone()
                guard isAuthorized else {
                    appStore.error = .permissionDenied("microphone")
                    appStore.showingError = true
                    return
                }
                _ = await PermissionService.requestSpeech()
                isRecording = true
                appStore.isTranscribing = true

                for try await text in try await appStore.speechService.start() {
                    transcribedText = text
                    appStore.speechToTextOutput = text
                }
            } catch {
                appStore.error = .unknown(error.localizedDescription)
                appStore.showingError = true
                isRecording = false
                appStore.isTranscribing = false
            }
        }
    }

    func stopRecording() {
        isRecording = false
        appStore.isTranscribing = false
        appStore.speechService.stop()
        let finalText = transcribedText
        transcribedText = ""
        guard !finalText.isEmpty else { return }
        appStore.addToHistory(message: finalText, role: .userSpoke)
    }
}
```

- [ ] **Step 2: Create SpeechToTextView**

```swift
// Features/SpeechToText/SpeechToTextView.swift
import SwiftUI

struct SpeechToTextView: View {
    @Environment(AppStore.self) private var appStore
    @State private var store: SpeechToTextStore?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Status indicator
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

                // Transcribed text display
                Text(store?.transcribedText ?? appStore.speechToTextOutput.isEmpty
                    ? "Tap the microphone to start"
                    : appStore.speechToTextOutput
                )
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 16))

                Spacer()

                // Record button
                Button {
                    if let store {
                        if store.isRecording {
                            store.stopRecording()
                        } else {
                            store.startRecording()
                        }
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
```

- [ ] **Step 3: Build check**
- [ ] **Step 4: Commit**

---

### Task 10: SignToSpeech Feature

**Files:**
- Create: `Features/SignToSpeech/SignToSpeechStore.swift`
- Create: `Features/SignToSpeech/SignToSpeechView.swift`
- Create: `Features/SignToSpeech/CameraPreviewView.swift`

**Interfaces:**
- Consumes: `AppStore`, `CameraService`, `SignLanguageInferencing`, `SpeechSynthesizerService`
- Produces: `SignToSpeechStore`, `SignToSpeechView`, `CameraPreviewView`

- [ ] **Step 1: Create CameraPreviewView (UIViewRepresentable)**

```swift
// Features/SignToSpeech/CameraPreviewView.swift
import AVFoundation
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let source: any PreviewSource

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        source.connect(to: view)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}
```

- [ ] **Step 2: Create SignToSpeechStore**

```swift
// Features/SignToSpeech/SignToSpeechStore.swift
import CoreImage
import Observation

@MainActor
@Observable
final class SignToSpeechStore {
    private let appStore: AppStore
    private var predictionTask: Task<Void, Never>?

    var predictedText: String = ""
    var isCapturing = false
    var isAuthorized = false

    init(appStore: AppStore) {
        self.appStore = appStore
    }

    func startCapture() {
        guard !isCapturing else { return }
        Task {
            do {
                isAuthorized = await PermissionService.requestCamera()
                guard isAuthorized else {
                    appStore.error = .permissionDenied("camera")
                    appStore.showingError = true
                    return
                }
                isCapturing = true
                appStore.isPredicting = true
                try await appStore.cameraService.start()

                // Consume pixel buffers — for now, just show camera is running.
                // The ML integration will replace this when the model is ready.
                predictionTask = Task { [weak self] in
                    for await _ in appStore.cameraService.pixelBufferStream {
                        // Stub: replace with inferencer.predict() when model loads
                        try? await Task.sleep(for: .milliseconds(500))
                        await MainActor.run {
                            self?.predictedText = "Sign detected..."
                            appStore.signPredictionOutput = "Sign detected..."
                        }
                    }
                }
            } catch {
                appStore.error = .cameraUnavailable
                appStore.showingError = true
                isCapturing = false
                appStore.isPredicting = false
            }
        }
    }

    func speakPrediction() {
        let text = predictedText
        guard !text.isEmpty else { return }
        Task {
            await appStore.synthesizerService.speak(text)
            appStore.addToHistory(message: text, role: .assistantSpoke)
        }
    }

    func stopCapture() {
        isCapturing = false
        appStore.isPredicting = false
        appStore.cameraService.stop()
        predictionTask?.cancel()
        predictionTask = nil
    }
}
```

- [ ] **Step 3: Create SignToSpeechView**

```swift
// Features/SignToSpeech/SignToSpeechView.swift
import SwiftUI

struct SignToSpeechView: View {
    @Environment(AppStore.self) private var appStore
    @State private var store: SignToSpeechStore?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Camera preview
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
                            .background(store.isCapturing ? Color.red : Color.accentColor, in: .capsule)
                        }

                        if store.isCapturing {
                            Button {
                                store.speakPrediction()
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.title2)
                                    .frame(width: 52, height: 52)
                                    .background(.tint, in: .circle)
                                    .foregroundStyle(.white)
                            }
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
}
```

- [ ] **Step 4: Build check**
- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add SignToSpeech feature with camera preview and speech synthesis"
```

---

### Task 11: Build & Verify Full Project

**Files:** None (verification pass)

- [ ] **Step 1: Delete old ContentView.swift**

```bash
cd /Users/hisyam/Documents/ADA/XcodeProject/c4-xcode/SignLanguageApp/SignLanguageApp
rm -f Features/Content/ContentView.swift Features/Content/.DS_Store
```

- [ ] **Step 2: Full clean build**

```bash
cd /Users/hisyam/Documents/ADA/XcodeProject/c4-xcode/SignLanguageApp
xcodebuild -scheme SignLanguageApp -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Final commit**

```bash
git add -A && git commit -m "chore: final build verification and cleanup"
```
