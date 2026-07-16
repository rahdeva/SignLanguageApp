//
//  CameraService.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

@preconcurrency import AVFoundation
import CoreImage
import OSLog

enum CameraError: LocalizedError {
    case addInputFailed, addOutputFailed, noCameraAvailable, noMicAvailable, notAuthorized, flipFailed

    var errorDescription: String? {
        switch self {
        case .addInputFailed: "Failed to add camera input"
        case .addOutputFailed: "Failed to add video output"
        case .noCameraAvailable: "No camera available on this device"
        case .noMicAvailable: "No microphone available on this device"
        case .notAuthorized: "Camera access not authorized"
        case .flipFailed: "Could not switch camera"
        }
    }
}

actor CameraService: PreviewSource {
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sampleBufferDelegate = CameraOutputDelegate()
    private var activeVideoInput: AVCaptureDeviceInput?
    private var hasConfiguredSession = false
    private var streamContinuation: AsyncStream<CVPixelBuffer>.Continuation?

    nonisolated(unsafe) let pixelBufferStream: AsyncStream<CVPixelBuffer>

    private(set) var currentPosition: AVCaptureDevice.Position = .front

    init() {
        var cont: AsyncStream<CVPixelBuffer>.Continuation?
        pixelBufferStream = AsyncStream { continuation in
            cont = continuation
        }
        streamContinuation = cont
        sampleBufferDelegate.continuation = cont
        currentPosition = .front
    }

    nonisolated func connect(to target: any PreviewTarget) {
        Task { await target.setSession(captureSession) }
    }

    func start() async throws {
        guard await PermissionService.requestCamera() else { throw CameraError.notAuthorized }
        if !hasConfiguredSession { try configureSession() }
        guard !captureSession.isRunning else { return }
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                captureSession.startRunning()
                continuation.resume()
            }
        }
    }

    func stop() {
        guard captureSession.isRunning else { return }
        DispatchQueue.global(qos: .background).async { [self] in
            captureSession.stopRunning()
        }
    }

    func flipCamera() async throws {
        guard let currentInput = activeVideoInput else { return }
        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .front ? .back : .front
        guard let newDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: newPosition)
            ?? .default(.builtInWideAngleCamera, for: .video, position: newPosition)
        else { throw CameraError.flipFailed }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        captureSession.removeInput(currentInput)
        do {
            activeVideoInput = try addInput(for: newDevice)
            currentPosition = newPosition
        } catch {
            captureSession.addInput(currentInput)
            throw error
        }
    }

    // MARK: - Private

    nonisolated private static let fallbackVideoDevice: AVCaptureDevice = {
        let device: AVCaptureDevice? = .default(.external, for: .video, position: .unspecified)
            ?? .default(.builtInWideAngleCamera, for: .video, position: .front)
        guard let camera = device else {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.signlanguageapp", category: "camera").error("No camera device found")
            return .default(.builtInWideAngleCamera, for: .video, position: .front)!
        }
        return camera
    }()

    private func configureSession() throws {
        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
            hasConfiguredSession = true
        }
        captureSession.sessionPreset = .high

        let frontDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? Self.fallbackVideoDevice
        activeVideoInput = try addInput(for: frontDevice)
        currentPosition = .front

        if let mic = AVCaptureDevice.default(for: .audio) {
            _ = try? addInput(for: mic)
        }

        videoOutput.setSampleBufferDelegate(sampleBufferDelegate, queue: .init(label: "camera.video.queue", qos: .userInitiated))
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
    var continuation: AsyncStream<CVPixelBuffer>.Continuation?

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        continuation?.yield(pixelBuffer)
    }
}
