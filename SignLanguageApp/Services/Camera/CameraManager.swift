//
//  CameraManager.swift
//  SignLanguageApp
//
//  Created by rahdeva on 16/07/26.
//  Updated for multi-modal Vision detection:
//    - Hand Pose    : 21 joints (wrist + 4 fingers × 5)
//    - Body Pose    : 17 joints (VNHumanBodyPoseObservation)
//    - Face/Mouth   : 8 mouth landmark points (VNFaceLandmarkRegion2D)
//  Total feature joints: 46  →  shape [window, 3, 46]
//

import AVFoundation
import Combine
import CoreML
import SwiftUI
import Vision

// MARK: - Inference Result
struct InferenceResult {
    let label: String
    let confidence: Double
    let top3: [(label: String, confidence: Double)]
}

// MARK: - Skeleton Points (hand overlay only)
struct SkeletonPoints {
    var handPoints: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]
}

// MARK: - Model Mode
enum ModelMode: String, CaseIterable {
    /// Hand-only: 21 joints → MyHandActionBisindoClassifier_1  [60, 3, 21]
    case handOnly   = "Hand Only"
    /// Full multi-modal: 46 joints → BisindoHandActionClassifier [60, 3, 46]
    case multiModal = "Multi-Modal"

    var totalJoints: Int    { self == .handOnly ? 21 : 46 }
    var sfSymbol:    String { self == .handOnly ? "hand.raised.fill" : "brain.filled.head.profile" }
}

// MARK: - CameraManager
class CameraManager: NSObject, ObservableObject, @unchecked Sendable {

    // MARK: - Published Properties (Main Thread)
    @Published var currentSign: String       = "Detecting..."
    @Published var currentConfidence: Double = 0.0
    @Published var topPredictions: [(label: String, confidence: Double)] = []
    @Published var bufferCount: Int          = 0
    @Published var skeleton: SkeletonPoints  = SkeletonPoints()
    @Published var isFrontCamera: Bool       = true
    @Published var isRunning: Bool           = false
    @Published var permissionGranted: Bool   = false
    @Published var modelMode: ModelMode        = .handOnly

    // Legacy accessor so ContentView / HandOverlayView compile without changes
    var handPoints: [VNHumanHandPoseObservation.JointName: CGPoint] { skeleton.handPoints }

    // MARK: - Camera & Session
    let session           = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()

    private let captureQueue = DispatchQueue(
        label: "com.dewaayam.SignLanguageApp.captureQueue",
        qos: .userInteractive
    )

    // MARK: - CoreML
    nonisolated(unsafe) private var mlModel: MLModel?

    // MARK: - Preview Layer
    nonisolated(unsafe) var previewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - Frame Buffer (captureQueue only)
    nonisolated(unsafe) private var frameBuffer: [[[Float]]] = []
    nonisolated(unsafe) private var emptyFrameCounter: Int   = 0

    /// Rolling-window size — must match Create ML training window exactly.
    private let windowSize = 60

    /// Run inference every N frames (~4 inferences/sec at 30fps).
    private let inferenceStride = 15

    nonisolated(unsafe) private var framesSinceInference: Int = 0

    // MARK: - Camera State Cache
    nonisolated(unsafe) private var currentIsFrontCamera: Bool = true
    /// Cached model mode for use on captureQueue (mirrors @Published modelMode)
    nonisolated(unsafe) private var cachedModelMode: ModelMode = .handOnly

    // MARK: - Joint Order (must match training data exactly)

    /// Hand joints — 21 keypoints
    private let handJoints: [VNHumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP,  .ringPIP,  .ringDIP,  .ringTip,
        .littleMCP,.littlePIP,.littleDIP,.littleTip
    ]

    /// Body joints — 17 keypoints
    private let bodyJoints: [VNHumanBodyPoseObservation.JointName] = [
        .nose,
        .leftEye,  .rightEye,
        .leftEar,  .rightEar,
        .leftShoulder,  .rightShoulder,
        .leftElbow,     .rightElbow,
        .leftWrist,     .rightWrist,
        .leftHip,       .rightHip,
        .leftKnee,      .rightKnee,
        .leftAnkle,     .rightAnkle
    ]

    /// Active joint count — updated in loadModel() when mode changes (captureQueue only)
    nonisolated(unsafe) private var activeJoints: Int = 21

    // MARK: - Reuse Buffer
    nonisolated(unsafe) private var reuseMultiArray: MLMultiArray? = nil

    override init() {
        super.init()
        loadModel()
        checkPermissions()
    }

    // MARK: - Model Loading
    private func loadModel() {
        let mode = modelMode   // capture before entering async block
        captureQueue.async { [weak self] in
            guard let self else { return }
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .all

                switch mode {
                case .handOnly:
                    // 21-joint hand-only model (generated Swift class)
                    let wrapper = try MyHandActionBisindoClassifier_1(configuration: config)
                    self.mlModel    = wrapper.model
                    self.activeJoints = 21

                case .multiModal:
                    // 46-joint multi-modal model (.mlpackage compiled to .mlmodelc in bundle)
                    guard let url = Bundle.main.url(forResource: "BisindoHandActionClassifier",
                                                    withExtension: "mlmodelc")
                              ?? Bundle.main.url(forResource: "BisindoHandActionClassifier",
                                                 withExtension: "mlpackage") else {
                        print("❌ BisindoHandActionClassifier not found in bundle.",
                              "Add BisindoHandActionClassifier.mlpackage to the Xcode target.")
                        return
                    }
                    self.mlModel    = try MLModel(contentsOf: url, configuration: config)
                    self.activeJoints = 46
                }

                self.cachedModelMode = mode

                // Re-allocate reuse buffer for the new shape [window, 3, activeJoints]
                self.reuseMultiArray = try? MLMultiArray(
                    shape: [NSNumber(value: self.windowSize),
                            3,
                            NSNumber(value: self.activeJoints)],
                    dataType: .float32
                )
                print("✅ Model loaded: \(mode.rawValue). Feature shape: [\(self.windowSize), 3, \(self.activeJoints)]")
            } catch {
                print("❌ Error loading CoreML model: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Permissions
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted { self?.setupCamera() }
                }
            }
        default:
            permissionGranted = false
        }
    }

    // MARK: - Camera Setup
    private func setupCamera() {
        captureQueue.async { [weak self] in
            guard let self else { return }

            let isFront = self.isFrontCamera
            self.currentIsFrontCamera = isFront

            self.session.beginConfiguration()
            self.session.sessionPreset = .vga640x480

            for input  in self.session.inputs  { self.session.removeInput(input) }
            for output in self.session.outputs { self.session.removeOutput(output) }

            let position: AVCaptureDevice.Position = isFront ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: position),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input)
            else { self.session.commitConfiguration(); return }

            self.session.addInput(input)

            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            self.videoDataOutput.setSampleBufferDelegate(self, queue: self.captureQueue)

            if self.session.canAddOutput(self.videoDataOutput) {
                self.session.addOutput(self.videoDataOutput)
                if let conn = self.videoDataOutput.connection(with: .video) {
                    // Do NOT set videoRotationAngle here — it only writes metadata;
                    // it does NOT physically rotate the pixel buffer data.
                    // The raw sensor buffer orientation is handled via
                    // CGImagePropertyOrientation in VNImageRequestHandler below.
                    if conn.isVideoMirroringSupported { conn.isVideoMirrored = false }
                }
            }

            self.session.commitConfiguration()
            self.session.startRunning()
            DispatchQueue.main.async { self.isRunning = self.session.isRunning }
        }
    }

    // MARK: - Public Controls
    func toggleCamera() {
        isFrontCamera.toggle()
        resetBuffer()
        setupCamera()
    }

    /// Switch between hand-only and multi-modal inference models.
    func switchModel(_ mode: ModelMode) {
        guard mode != modelMode else { return }
        modelMode = mode
        resetBuffer()
        loadModel()
    }

    func resetBuffer() {
        captureQueue.async { [weak self] in
            guard let self else { return }
            self.frameBuffer.removeAll()
            self.emptyFrameCounter      = 0
            self.framesSinceInference   = 0
            DispatchQueue.main.async {
                self.bufferCount     = 0
                self.currentSign     = "Detecting..."
                self.currentConfidence = 0.0
                self.skeleton        = SkeletonPoints()
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
nonisolated extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // iPhone sensor raw orientation (no rotation applied to the buffer):
        //   Back camera in portrait  → .right   (scene top is on the right of the raw landscape frame)
        //   Front camera in portrait → .leftMirrored (same + horizontal mirror from selfie lens)
        let orientation: CGImagePropertyOrientation = currentIsFrontCamera ? .leftMirrored : .right
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: orientation,
                                            options: [:])

        // ── 1. Build Vision request (hand only) ───────────────────────────────
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 1

        do {
            try handler.perform([handRequest])
        } catch {
            handleEmptyFrame()
            return
        }

        // ── 2. Extract Hand keypoints (21: wrist + 5 fingers × 4) ─────────────
        var handDisplay: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]
        var handFeats: [[Float]] = []

        if let obs = handRequest.results?.first,
           let pts = try? obs.recognizedPoints(.all) {
            for j in handJoints {
                if let p = pts[j], p.confidence > 0.1 {
                    handFeats.append([Float(p.location.x),
                                      Float(p.location.y),
                                      Float(p.confidence)])
                    handDisplay[j] = CGPoint(x: p.location.x, y: p.location.y)
                } else {
                    handFeats.append([0, 0, 0])
                }
            }
        } else {
            handFeats = Array(repeating: [0, 0, 0], count: handJoints.count)
        }

        // ── 3. Combine features (hand-only, 21 joints) ─────────────────────────
        let frameJoints: [[Float]] = handFeats

        // Guard: no hand detected → treat as empty
        guard !handDisplay.isEmpty else {
            handleEmptyFrame()
            return
        }

        // ── 4. Update rolling buffer ───────────────────────────────────────────
        emptyFrameCounter = 0
        frameBuffer.append(frameJoints)
        if frameBuffer.count > windowSize { frameBuffer.removeFirst() }

        let count      = frameBuffer.count
        let bufferFull = count == windowSize

        // ── 5. Convert coordinates → layer pixels on main thread ───────────────
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.bufferCount = count
            if let layer = self.previewLayer {
                // Vision (.right / .leftMirrored) returns portrait coordinates with
                // origin at BOTTOM-LEFT and y going UP.
                // layerPointConverted() expects AVFoundation "capture device" coordinates:
                // origin at TOP-LEFT of the RAW LANDSCAPE sensor frame, y going DOWN.
                //
                // Vision coordinates are 180° rotated relative to the capture device
                // coordinate space expected by layerPointConverted. Apply 180° rotation
                // (flip both axes around the centre) to align the skeleton overlay.
                func toCapture(_ p: CGPoint) -> CGPoint { CGPoint(x: 1 - p.x, y: 1 - p.y) }

                let convertedHand = Dictionary(uniqueKeysWithValues: handDisplay.map {
                    ($0.key, layer.layerPointConverted(fromCaptureDevicePoint: toCapture($0.value)))
                })
                self.skeleton = SkeletonPoints(handPoints: convertedHand)
            } else {
                self.skeleton = SkeletonPoints(handPoints: handDisplay)
            }
        }

        // ── 8. Stride-gated inference ──────────────────────────────────────────
        framesSinceInference += 1
        guard bufferFull, framesSinceInference >= inferenceStride else { return }
        framesSinceInference = 0

        let snapshot = frameBuffer
        if let result = runInference(snapshot: snapshot) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.topPredictions     = result.top3
                self.currentConfidence  = result.confidence
                self.currentSign        = result.confidence >= 0.50 ? result.label : "Uncertain"
            }
        }
    }

    // MARK: - Empty Frame Handling
    private func handleEmptyFrame() {
        emptyFrameCounter += 1
        DispatchQueue.main.async { self.skeleton = SkeletonPoints() }

        if emptyFrameCounter >= 30 {
            frameBuffer.removeAll()
            emptyFrameCounter     = 0
            framesSinceInference  = 0
            DispatchQueue.main.async {
                self.bufferCount       = 0
                self.currentSign       = "Detecting..."
                self.currentConfidence = 0.0
            }
        } else if !frameBuffer.isEmpty {
            let zero = [[Float]](repeating: [0, 0, 0], count: activeJoints)
            frameBuffer.append(zero)
            if frameBuffer.count > windowSize { frameBuffer.removeFirst() }
            let c = frameBuffer.count
            DispatchQueue.main.async { self.bufferCount = c }
        }
    }

    // MARK: - CoreML Inference
    private func runInference(snapshot: [[[Float]]]) -> InferenceResult? {
        guard let model = mlModel, snapshot.count == windowSize else { return nil }

        let joints = activeJoints
        guard let ma = reuseMultiArray ?? (try? MLMultiArray(
            shape: [NSNumber(value: windowSize), 3, NSNumber(value: joints)],
            dataType: .float32)) else { return nil }

        // Fill: shape [window, 3, joints] → index = f*(3*joints) + c*joints + j
        let stride3J = 3 * joints
        for f in 0..<windowSize {
            for c in 0..<3 {
                for j in 0..<joints {
                    ma[f * stride3J + c * joints + j] =
                        NSNumber(value: snapshot[f][j][c])
                }
            }
        }

        do {
            let features = try MLDictionaryFeatureProvider(dictionary: ["poses": ma])
            let raw      = try model.prediction(from: features)

            let label = raw.featureValue(for: "label")?.stringValue ?? ""
            guard !label.isEmpty,
                  let probDict = raw.featureValue(for: "labelProbabilities")?
                                    .dictionaryValue as? [String: Double]
            else { return nil }

            let confidence = probDict[label] ?? 0.0
            let top3 = probDict.sorted { $0.value > $1.value }.prefix(3)
                .map { (label: $0.key, confidence: $0.value) }

            return InferenceResult(label: label, confidence: confidence, top3: top3)
        } catch {
            print("CoreML inference error: \(error)")
            return nil
        }
    }
}
