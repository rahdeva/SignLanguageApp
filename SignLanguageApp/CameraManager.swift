//
//  CameraManager.swift
//  SignLanguageApp
//
//  Created by rahdeva on 16/07/26.
//

import AVFoundation
import Combine
import CoreML
import SwiftUI
import Vision

// MARK: - Inference Result (value type, thread-safe to pass across queues)
struct InferenceResult {
    let label: String
    let confidence: Double
    let top3: [(label: String, confidence: Double)]
}

class CameraManager: NSObject, ObservableObject, @unchecked Sendable {

    // MARK: - Published Properties (Main Thread)
    @Published var currentSign: String = "Detecting..."
    @Published var currentConfidence: Double = 0.0
    @Published var topPredictions: [(label: String, confidence: Double)] = []
    @Published var bufferCount: Int = 0
    @Published var handPoints: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]
    @Published var isFrontCamera: Bool = true
    @Published var isRunning: Bool = false
    @Published var permissionGranted: Bool = false

    // MARK: - Camera & Session
    let session = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()

    /// Dedicated serial queue for all capture + inference work.
    /// Using `.userInteractive` so Vision and CoreML are prioritized by the OS.
    private let captureQueue = DispatchQueue(
        label: "com.dewaayam.SignLanguageApp.captureQueue",
        qos: .userInteractive
    )

    // MARK: - CoreML
    nonisolated(unsafe) private var mlModel: MLModel?

    // MARK: - Preview Layer (set by CameraPreviewView)
    nonisolated(unsafe) var previewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - Frame Buffer (captureQueue only)
    nonisolated(unsafe) private var frameBuffer: [[[Float]]] = []
    nonisolated(unsafe) private var emptyFrameCounter: Int = 0

    /// Rolling-window size — must match Create ML training window exactly.
    private let windowSize = 60

    /// Run inference every N frames. 15 → ~4 inferences/sec at 30fps.
    private let inferenceStride = 15

    nonisolated(unsafe) private var framesSinceInference: Int = 0

    // MARK: - Camera State Cache (captureQueue)
    nonisolated(unsafe) private var currentIsFrontCamera: Bool = true

    // MARK: - Joint Order (must match training data exactly)
    private let orderedJoints: [VNHumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip
    ]

    // MARK: - MLMultiArray Reuse Buffer
    // Pre-allocated once and reused every inference to avoid repeated heap allocation.
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

                // Pre-allocate the reuse buffer once
                self.reuseMultiArray = try? MLMultiArray(
                    shape: [NSNumber(value: self.windowSize), 3, 21],
                    dataType: .float32
                )
                print("✅ Model loaded on captureQueue. mlModel ready.")
            } catch {
                print("❌ Error loading CoreML model: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Permissions
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.permissionGranted = true
            self.setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted { self?.setupCamera() }
                }
            }
        default:
            self.permissionGranted = false
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
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
                self.session.commitConfiguration(); return
            }

            guard let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration(); return
            }
            self.session.addInput(input)

            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            self.videoDataOutput.setSampleBufferDelegate(self, queue: self.captureQueue)

            if self.session.canAddOutput(self.videoDataOutput) {
                self.session.addOutput(self.videoDataOutput)
                if let connection = self.videoDataOutput.connection(with: .video) {
                    if #available(iOS 17.0, *) {
                        if connection.isVideoRotationAngleSupported(90.0) {
                            connection.videoRotationAngle = 90.0
                        }
                    } else {
                        if connection.isVideoOrientationSupported {
                            connection.videoOrientation = .portrait
                        }
                    }
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = false
                    }
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
            self.emptyFrameCounter = 0
            self.framesSinceInference = 0
            DispatchQueue.main.async {
                self.bufferCount = 0
                self.currentSign = "Detecting..."
                self.currentConfidence = 0.0
                self.handPoints = [:]
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
nonisolated extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // ── 1. Run Vision hand-pose detection ─────────────────────────────────
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1

        let orientation: CGImagePropertyOrientation = currentIsFrontCamera ? .leftMirrored : .right
        do {
            try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
                .perform([request])
        } catch {
            handleEmptyFrame()
            return
        }

        guard let observation = request.results?.first else {
            handleEmptyFrame()
            return
        }

        // ── 2. Extract keypoints ────────────────────────────────────────────────
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else {
            handleEmptyFrame()
            return
        }

        var frameJoints: [[Float]] = []
        var displayPoints: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]

        for joint in orderedJoints {
            if let p = recognizedPoints[joint], p.confidence > 0.1 {
                frameJoints.append([Float(p.location.x), Float(p.location.y), Float(p.confidence)])
                displayPoints[joint] = CGPoint(x: p.location.x, y: p.location.y)
            } else {
                frameJoints.append([0, 0, 0])
            }
        }

        // ── 3. Update rolling buffer ────────────────────────────────────────────
        emptyFrameCounter = 0
        frameBuffer.append(frameJoints)
        if frameBuffer.count > windowSize { frameBuffer.removeFirst() }

        let count = frameBuffer.count
        let bufferFull = count == windowSize

        // ── 4. Convert coords → layer pixels on main thread ────────────────────
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.bufferCount = count
            if let layer = self.previewLayer {
                self.handPoints = Dictionary(uniqueKeysWithValues: displayPoints.map {
                    ($0.key, layer.layerPointConverted(fromCaptureDevicePoint: $0.value))
                })
            } else {
                self.handPoints = displayPoints
            }
        }

        // ── 5. Stride-gated inference ───────────────────────────────────────────
        framesSinceInference += 1
        guard bufferFull, framesSinceInference >= inferenceStride else { return }
        framesSinceInference = 0

        // Snapshot (O(1) CoW) then infer synchronously on captureQueue
        let snapshot = frameBuffer
        if let result = runInference(snapshot: snapshot) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.topPredictions    = result.top3
                self.currentConfidence = result.confidence
                self.currentSign       = result.confidence >= 0.50 ? result.label : "Uncertain"
            }
        }
    }

    // MARK: - Empty Frame Handling
    private func handleEmptyFrame() {
        emptyFrameCounter += 1
        DispatchQueue.main.async { self.handPoints = [:] }

        if emptyFrameCounter >= 30 {
            frameBuffer.removeAll()
            emptyFrameCounter = 0
            framesSinceInference = 0
            DispatchQueue.main.async {
                self.bufferCount = 0
                self.currentSign = "Detecting..."
                self.currentConfidence = 0.0
            }
        } else if !frameBuffer.isEmpty {
            let zero = [[Float]](repeating: [0, 0, 0], count: 21)
            frameBuffer.append(zero)
            if frameBuffer.count > windowSize { frameBuffer.removeFirst() }
            let c = frameBuffer.count
            DispatchQueue.main.async { self.bufferCount = c }
        }
    }

    // MARK: - CoreML Inference (synchronous, runs on captureQueue)
    private func runInference(snapshot: [[[Float]]]) -> InferenceResult? {
        guard let model = mlModel, snapshot.count == windowSize else { return nil }

        // Reuse pre-allocated MLMultiArray; fall back to a fresh one if needed.
        guard let ma = reuseMultiArray ?? (try? MLMultiArray(
            shape: [NSNumber(value: windowSize), 3, 21], dataType: .float32)) else { return nil }

        // Fill: shape [60, 3, 21] → index = f*63 + c*21 + j
        for f in 0..<windowSize {
            for c in 0..<3 {
                for j in 0..<21 {
                    ma[f * 63 + c * 21 + j] = NSNumber(value: snapshot[f][j][c])
                }
            }
        }

        do {
            let features = try MLDictionaryFeatureProvider(dictionary: ["poses": ma])
            let raw = try model.prediction(from: features)

            // ── DEBUG: print raw output ────────────────────────────────────────
            print("=== RAW OUTPUT ===")
            print(raw)
            for name in raw.featureNames {
                print("[\(name)]:", raw.featureValue(for: name) as Any)
            }
            print("==================")
            // ──────────────────────────────────────────────────────────────────

            let label = raw.featureValue(for: "label")?.stringValue ?? ""
            guard !label.isEmpty,
                  let probDict = raw.featureValue(for: "labelProbabilities")?.dictionaryValue as? [String: Double]
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
