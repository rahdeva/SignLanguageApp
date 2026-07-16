import AVFoundation
import CoreImage
import OSLog

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
    private var streamContinuation: AsyncStream<CVPixelBuffer>.Continuation?

    nonisolated(unsafe) let pixelBufferStream: AsyncStream<CVPixelBuffer>

    init() {
        var cont: AsyncStream<CVPixelBuffer>.Continuation?
        pixelBufferStream = AsyncStream { continuation in
            cont = continuation
        }
        streamContinuation = cont
    }

    nonisolated func connect(to target: any PreviewTarget) {
        Task { await target.setSession(captureSession) }
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
        streamContinuation?.finish()
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

        let camera = CameraService.defaultVideoDevice
        activeVideoInput = try addInput(for: camera)

        if let mic = AVCaptureDevice.default(for: .audio) {
            _ = try? addInput(for: mic)
        }

        videoOutput.setSampleBufferDelegate(
            CameraOutputDelegate(continuation: streamContinuation),
            queue: .init(label: "camera.video.queue", qos: .userInitiated)
        )
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.automaticallyConfiguresOutputBufferDimensions = true

        guard captureSession.canAddOutput(videoOutput) else { throw CameraError.addOutputFailed }
        captureSession.addOutput(videoOutput)
    }

    private static let defaultVideoDevice: AVCaptureDevice = {
        let device: AVCaptureDevice? = .default(.external, for: .video, position: .unspecified)
            ?? .default(.builtInWideAngleCamera, for: .video, position: .front)
        guard let camera = device else {
            AppLogger.default.error("No camera device found")
            return .default(.builtInWideAngleCamera, for: .video, position: .front)!
        }
        return camera
    }()

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
