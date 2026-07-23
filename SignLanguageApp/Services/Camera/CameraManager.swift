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

// MARK: - Skeleton Points (hand & eye overlay)
struct SkeletonPoints {
    var handPoints: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]
    var leftEyePoints: [CGPoint] = []
    var rightEyePoints: [CGPoint] = []
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

    // Face & Eye Tracking
    @Published var isFaceDetectionEnabled: Bool = true
    @Published var isFaceDetected: Bool      = false
    @Published var isLeftEyeClosed: Bool     = false
    @Published var isRightEyeClosed: Bool    = false
    @Published var leftEAR: Double           = 0.0
    @Published var rightEAR: Double          = 0.0

    // Legacy accessor so ContentView / HandOverlayView compile without changes
    var handPoints: [VNHumanHandPoseObservation.JointName: CGPoint] { skeleton.handPoints }

    // MARK: - Camera & Session
    let session           = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()

    private let captureQueue = DispatchQueue(
        label: "com.dewaayam.stella.captureQueue",
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
    /// Cached Vision region of interest (ROI) matching the visible cropped preview rectangle exactly
    nonisolated(unsafe) private var cachedVisionROI: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)

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

            // After reconfiguration the preview layer gets a fresh connection.
            // Re-apply mirroring immediately (orientation is auto-handled by
            // AVCaptureVideoPreviewLayer).
            if let previewConn = self.previewLayer?.connection {
                if previewConn.isVideoMirroringSupported {
                    previewConn.automaticallyAdjustsVideoMirroring = false
                    previewConn.isVideoMirrored = isFront
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isRunning = self.session.isRunning
                self.configurePreviewLayerOrientation()
            }
        }
    }

    /// Configures the AVCaptureVideoPreviewLayer and AVCaptureVideoDataOutput connection orientation and mirroring.
    func configurePreviewLayerOrientation() {
        if let layer = previewLayer, let connection = layer.connection {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = isFrontCamera
            }
        }
        if let videoConnection = videoDataOutput.connection(with: .video) {
            if videoConnection.isVideoOrientationSupported {
                videoConnection.videoOrientation = .portrait
            }
            if videoConnection.isVideoMirroringSupported {
                videoConnection.automaticallyAdjustsVideoMirroring = false
                videoConnection.isVideoMirrored = isFrontCamera
            }
        }
    }
    
    // MARK: - Session Controls
    func startSession() {
        guard permissionGranted else { return }
        captureQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isRunning = self.session.isRunning
                }
            }
        }
    }

    func stopSession() {
        captureQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isRunning = self.session.isRunning
                }
            }
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

    /// Updates the region of interest (ROI) so Vision only detects hands inside the exact area visible in the UI preview.
    func updateROI() {
        guard let layer = previewLayer, layer.bounds.width > 0, layer.bounds.height > 0 else { return }
        let captureRect = layer.metadataOutputRectConverted(fromLayerRect: layer.bounds)
        guard !captureRect.isEmpty && !captureRect.isInfinite else { return }
        // Convert capture device coordinates (origin top-left) to Vision portrait coordinates (origin bottom-left):
        // captureX = 1 - visionX  =>  visionX = 1 - captureX - captureWidth
        // captureY = 1 - visionY  =>  visionY = 1 - captureY - captureHeight
        let vx = max(0, min(1, 1.0 - captureRect.origin.x - captureRect.width))
        let vy = max(0, min(1, 1.0 - captureRect.origin.y - captureRect.height))
        let vw = max(0, min(1 - vx, captureRect.width))
        let vh = max(0, min(1 - vy, captureRect.height))
        guard vw > 0 && vh > 0 else { return }
        cachedVisionROI = CGRect(x: vx, y: vy, width: vw, height: vh)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
nonisolated extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // ── 0. Crop image buffer to exact visible UI camera preview rectangle ──
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        let cw: CGFloat = previewLayer?.bounds.width ?? 393
        let ch: CGFloat = previewLayer?.bounds.height ?? 360
        let containerAspect = cw / ch

        let imgExtent = ciImage.extent
        let imageAspect = imgExtent.width / imgExtent.height

        var cropRect = imgExtent
        if containerAspect > imageAspect {
            // Container is wider than image aspect ratio: crop top & bottom overflow
            let visibleH = imgExtent.width / containerAspect
            let offsetY = (imgExtent.height - visibleH) / 2.0
            cropRect = CGRect(x: imgExtent.origin.x, y: imgExtent.origin.y + offsetY, width: imgExtent.width, height: visibleH)
        } else {
            // Container is taller than image aspect ratio: crop left & right overflow
            let visibleW = imgExtent.height * containerAspect
            let offsetX = (imgExtent.width - visibleW) / 2.0
            cropRect = CGRect(x: imgExtent.origin.x + offsetX, y: imgExtent.origin.y, width: visibleW, height: imgExtent.height)
        }

        let croppedImage = ciImage.cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y))
        let handler = VNImageRequestHandler(ciImage: croppedImage, options: [:])

        // ── 1. Build Vision requests (hand & face) ─────────────────────────────
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 1

        let faceEnabled = isFaceDetectionEnabled
        let faceRequest: VNDetectFaceLandmarksRequest? = faceEnabled ? VNDetectFaceLandmarksRequest() : nil

        do {
            var requests: [VNRequest] = [handRequest]
            if let fr = faceRequest { requests.append(fr) }
            try handler.perform(requests)
        } catch {
            handleEmptyFrame(faceDetected: false, leftClosed: false, rightClosed: false)
            return
        }

        var faceDetected = false
        var leftClosed = false
        var rightClosed = false
        var valLeftEAR = 0.0
        var valRightEAR = 0.0
        var leftEyeDisplay: [CGPoint] = []
        var rightEyeDisplay: [CGPoint] = []

        if let faceObs = faceRequest?.results?.first, let landmarks = faceObs.landmarks {
            faceDetected = true
            let bbox = faceObs.boundingBox

            if let leftEye = landmarks.leftEye {
                if let ear = Self.calculateEAR(region: leftEye, bbox: bbox) {
                    valLeftEAR = ear
                    leftClosed = ear < 0.18
                }
                leftEyeDisplay = leftEye.normalizedPoints.map { p in
                    CGPoint(
                        x: bbox.origin.x + p.x * bbox.width,
                        y: bbox.origin.y + p.y * bbox.height
                    )
                }
            }

            if let rightEye = landmarks.rightEye {
                if let ear = Self.calculateEAR(region: rightEye, bbox: bbox) {
                    valRightEAR = ear
                    rightClosed = ear < 0.18
                }
                rightEyeDisplay = rightEye.normalizedPoints.map { p in
                    CGPoint(
                        x: bbox.origin.x + p.x * bbox.width,
                        y: bbox.origin.y + p.y * bbox.height
                    )
                }
            }
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

        // Guard: no hand detected → treat as empty for hand buffer, but update eye states
        guard !handDisplay.isEmpty else {
            handleEmptyFrame(
                faceDetected: faceDetected,
                leftClosed: leftClosed,
                rightClosed: rightClosed,
                leftEAR: valLeftEAR,
                rightEAR: valRightEAR,
                leftEyeDisplay: leftEyeDisplay,
                rightEyeDisplay: rightEyeDisplay
            )
            return
        }

        // ── 4. Update rolling buffer ───────────────────────────────────────────
        emptyFrameCounter = 0
        frameBuffer.append(frameJoints)
        if frameBuffer.count > windowSize { frameBuffer.removeFirst() }

        let count      = frameBuffer.count
        let bufferFull = count == windowSize

        // ── 5. Convert coordinates → container pixels on main thread ───────────
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.bufferCount = count
            self.isFaceDetected = faceDetected
            self.isLeftEyeClosed = leftClosed
            self.isRightEyeClosed = rightClosed
            self.leftEAR = valLeftEAR
            self.rightEAR = valRightEAR
            
            let cw: CGFloat = self.previewLayer?.bounds.width ?? 393
            let ch: CGFloat = self.previewLayer?.bounds.height ?? 360

            let convertedHand = Dictionary(uniqueKeysWithValues: handDisplay.map {
                ($0.key, CGPoint(x: $0.value.x * cw, y: (1.0 - $0.value.y) * ch))
            })
            let convertedLeftEye = leftEyeDisplay.map {
                CGPoint(x: $0.x * cw, y: (1.0 - $0.y) * ch)
            }
            let convertedRightEye = rightEyeDisplay.map {
                CGPoint(x: $0.x * cw, y: (1.0 - $0.y) * ch)
            }
            self.skeleton = SkeletonPoints(
                handPoints: convertedHand,
                leftEyePoints: convertedLeftEye,
                rightEyePoints: convertedRightEye
            )
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
    private func handleEmptyFrame(
        faceDetected: Bool = false,
        leftClosed: Bool = false,
        rightClosed: Bool = false,
        leftEAR: Double = 0.0,
        rightEAR: Double = 0.0,
        leftEyeDisplay: [CGPoint] = [],
        rightEyeDisplay: [CGPoint] = []
    ) {
        emptyFrameCounter += 1
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let cw: CGFloat = self.previewLayer?.bounds.width ?? 393
            let ch: CGFloat = self.previewLayer?.bounds.height ?? 360

            let convertedLeftEye = leftEyeDisplay.map {
                CGPoint(x: $0.x * cw, y: (1.0 - $0.y) * ch)
            }
            let convertedRightEye = rightEyeDisplay.map {
                CGPoint(x: $0.x * cw, y: (1.0 - $0.y) * ch)
            }
            self.skeleton = SkeletonPoints(
                handPoints: [:],
                leftEyePoints: convertedLeftEye,
                rightEyePoints: convertedRightEye
            )
            self.isFaceDetected = faceDetected
            self.isLeftEyeClosed = leftClosed
            self.isRightEyeClosed = rightClosed
            self.leftEAR = leftEAR
            self.rightEAR = rightEAR
        }

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

    // MARK: - Eye Aspect Ratio (EAR) Calculation
    private static func calculateEAR(region: VNFaceLandmarkRegion2D?, bbox: CGRect) -> Double? {
        guard let region = region, region.pointCount >= 6 else { return nil }
        let pts = region.normalizedPoints
        
        let p: [CGPoint] = pts.map { pt in
            CGPoint(x: pt.x * bbox.width, y: pt.y * bbox.height)
        }

        let dxW = p[0].x - p[3].x
        let dyW = p[0].y - p[3].y
        let width = sqrt(dxW * dxW + dyW * dyW)
        guard width > 0.0001 else { return nil }

        let dxH1 = p[1].x - p[5].x
        let dyH1 = p[1].y - p[5].y
        let h1 = sqrt(dxH1 * dxH1 + dyH1 * dyH1)

        let dxH2 = p[2].x - p[4].x
        let dyH2 = p[2].y - p[4].y
        let h2 = sqrt(dxH2 * dxH2 + dyH2 * dyH2)

        return Double((h1 + h2) / (2.0 * width))
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
