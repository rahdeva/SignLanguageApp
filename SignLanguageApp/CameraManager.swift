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

// MARK: - Multi-modal Skeleton Points (for overlay rendering)
struct SkeletonPoints {
    var handPoints:  [VNHumanHandPoseObservation.JointName: CGPoint]  = [:]
    var bodyPoints:  [VNHumanBodyPoseObservation.JointName: CGPoint]   = [:]
    var mouthPoints: [CGPoint]                                          = []  // 8 mouth contour pts
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

    /// Total joint count: hand(21) + body(17) + mouth(8) = 46
    private let totalJoints = 46
    private let mouthJointCount = 8  // indices 38..45 in the combined vector

    // MARK: - Reuse Buffer
    nonisolated(unsafe) private var reuseMultiArray: MLMultiArray? = nil

    override init() {
        super.init()
        loadModel()
        checkPermissions()
    }

    // MARK: - Model Loading
    private func loadModel() {
        captureQueue.async { [weak self] in
            guard let self else { return }
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .all
                let wrapper = try MyHandActionBisindoClassifier_1(configuration: config)
                self.mlModel = wrapper.model

                // Pre-allocate reuse buffer — shape [window, 3, totalJoints]
                self.reuseMultiArray = try? MLMultiArray(
                    shape: [NSNumber(value: self.windowSize),
                            3,
                            NSNumber(value: self.totalJoints)],
                    dataType: .float32
                )
                print("✅ Model loaded. Feature shape: [\(self.windowSize), 3, \(self.totalJoints)]")
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
                    if #available(iOS 17.0, *) {
                        if conn.isVideoRotationAngleSupported(90.0) {
                            conn.videoRotationAngle = 90.0
                        }
                    } else if conn.isVideoOrientationSupported {
                        conn.videoOrientation = .portrait
                    }
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

        let orientation: CGImagePropertyOrientation = currentIsFrontCamera ? .leftMirrored : .right
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: orientation,
                                            options: [:])

        // ── 1. Build Vision requests ───────────────────────────────────────────
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 1

        let bodyRequest = VNDetectHumanBodyPoseRequest()

        let faceRequest = VNDetectFaceLandmarksRequest()

        do {
            try handler.perform([handRequest, bodyRequest, faceRequest])
        } catch {
            handleEmptyFrame()
            return
        }

        // ── 2. Extract Hand keypoints (21) ────────────────────────────────────
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

        // ── 3. Extract Body keypoints (17) ────────────────────────────────────
        var bodyDisplay: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        var bodyFeats: [[Float]] = []

        if let obs = bodyRequest.results?.first,
           let pts = try? obs.recognizedPoints(.all) {
            for j in bodyJoints {
                if let p = pts[j], p.confidence > 0.1 {
                    bodyFeats.append([Float(p.location.x),
                                      Float(p.location.y),
                                      Float(p.confidence)])
                    bodyDisplay[j] = CGPoint(x: p.location.x, y: p.location.y)
                } else {
                    bodyFeats.append([0, 0, 0])
                }
            }
        } else {
            bodyFeats = Array(repeating: [0, 0, 0], count: bodyJoints.count)
        }

        // ── 4. Extract Face / Mouth keypoints (8) ─────────────────────────────
        var mouthDisplay: [CGPoint] = []
        var mouthFeats: [[Float]] = []

        if let faceObs = faceRequest.results?.first,
           let landmarks = faceObs.landmarks,
           let outerLips = landmarks.outerLips {

            // Sample 8 evenly-spaced points from the outer lip contour
            let allPts = outerLips.normalizedPoints   // in face bounding box coords
            let faceBox = faceObs.boundingBox         // in image-normalised coords
            let step = max(1, allPts.count / mouthJointCount)
            let sampled = stride(from: 0, to: allPts.count, by: step).prefix(mouthJointCount).map {
                allPts[$0]
            }
            // Convert face-local coordinates → image-normalised coordinates
            for lp in sampled {
                let imgX = Float(faceBox.minX + lp.x * faceBox.width)
                let imgY = Float(faceBox.minY + lp.y * faceBox.height)
                mouthFeats.append([imgX, imgY, 1.0])
                mouthDisplay.append(CGPoint(x: Double(imgX), y: Double(imgY)))
            }
        }
        // Zero-pad if fewer than 8 mouth points detected
        while mouthFeats.count < mouthJointCount { mouthFeats.append([0, 0, 0]) }
        while mouthDisplay.count < mouthJointCount { mouthDisplay.append(.zero) }

        // ── 5. Combine features ────────────────────────────────────────────────
        // frameJoints[i] = [x, y, confidence]  for i in 0..<totalJoints (46)
        let frameJoints: [[Float]] = handFeats + bodyFeats + mouthFeats

        // Guard: if *everything* is zero (no detection at all), treat as empty
        let hasAnyDetection = !handDisplay.isEmpty || !bodyDisplay.isEmpty || !mouthDisplay.isEmpty
        guard hasAnyDetection else {
            handleEmptyFrame()
            return
        }

        // ── 6. Update rolling buffer ───────────────────────────────────────────
        emptyFrameCounter = 0
        frameBuffer.append(frameJoints)
        if frameBuffer.count > windowSize { frameBuffer.removeFirst() }

        let count     = frameBuffer.count
        let bufferFull = count == windowSize

        // ── 7. Convert coordinates → layer pixels on main thread ───────────────
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.bufferCount = count
            if let layer = self.previewLayer {
                let convertedHand = Dictionary(uniqueKeysWithValues: handDisplay.map {
                    ($0.key, layer.layerPointConverted(fromCaptureDevicePoint: $0.value))
                })
                let convertedBody = Dictionary(uniqueKeysWithValues: bodyDisplay.map {
                    ($0.key, layer.layerPointConverted(fromCaptureDevicePoint: $0.value))
                })
                let convertedMouth = mouthDisplay.map {
                    layer.layerPointConverted(fromCaptureDevicePoint: $0)
                }
                self.skeleton = SkeletonPoints(handPoints: convertedHand,
                                               bodyPoints: convertedBody,
                                               mouthPoints: convertedMouth)
            } else {
                self.skeleton = SkeletonPoints(handPoints: handDisplay,
                                               bodyPoints: bodyDisplay,
                                               mouthPoints: mouthDisplay)
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
            let zero = [[Float]](repeating: [0, 0, 0], count: totalJoints)
            frameBuffer.append(zero)
            if frameBuffer.count > windowSize { frameBuffer.removeFirst() }
            let c = frameBuffer.count
            DispatchQueue.main.async { self.bufferCount = c }
        }
    }

    // MARK: - CoreML Inference
    private func runInference(snapshot: [[[Float]]]) -> InferenceResult? {
        guard let model = mlModel, snapshot.count == windowSize else { return nil }

        guard let ma = reuseMultiArray ?? (try? MLMultiArray(
            shape: [NSNumber(value: windowSize), 3, NSNumber(value: totalJoints)],
            dataType: .float32)) else { return nil }

        // Fill: shape [60, 3, 46] → index = f*(3*46) + c*46 + j
        let stride3J = 3 * totalJoints
        for f in 0..<windowSize {
            for c in 0..<3 {
                for j in 0..<totalJoints {
                    ma[f * stride3J + c * totalJoints + j] =
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
