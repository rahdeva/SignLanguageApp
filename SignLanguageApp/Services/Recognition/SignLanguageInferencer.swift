//
//  SignLanguageInferencer.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import CoreImage
import CoreML
import Vision

/// Errors thrown during model loading or inference.
enum InferenceError: LocalizedError {
    case modelNotFound
    case modelLoadFailed(Error)
    case predictionFailed(Error)
    case invalidInput

    var errorDescription: String? {
        switch self {
        case .modelNotFound: "Core ML model not found in bundle"
        case .modelLoadFailed(let error):
            "Model load failed: \(error.localizedDescription)"
        case .predictionFailed(let error):
            "Prediction failed: \(error.localizedDescription)"
        case .invalidInput: "Invalid input buffer"
        }
    }
}

/// Interface for sign-language inference. Team can provide different implementations.
protocol SignLanguageInferencing: Actor, Sendable {
    func predict(_ pixelBuffer: CVPixelBuffer) async throws -> SignPrediction
    func reset() async
}

/// Loads a Core ML hand-action model and runs inference on Vision hand poses.
actor SignLanguageInferencer: SignLanguageInferencing {
    private static let modelName = "MyHandActionBisindoClassifier 1"
    private static let frameCount = 60
    private static let channels = 3

    private let jointNames: [VNHumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip,
    ]

    private var model: MLModel?
    private var poseFrames: [[Double]] = []

    init() {}

    /// Load `.mlmodelc` (or `.mlmodel`) from the app bundle.
    func loadModel(named name: String = "MyHandActionBisindoClassifier 1") async throws {
        guard
            let url = Bundle.main.url(
                forResource: name,
                withExtension: "mlmodelc"
            )
                ?? Bundle.main.url(forResource: name, withExtension: "mlmodel")
        else { throw InferenceError.modelNotFound }

        let config = MLModelConfiguration()
        config.computeUnits = .all
        do {
            model = try await MLModel.load(
                contentsOf: url,
                configuration: config
            )
        } catch {
            throw InferenceError.modelLoadFailed(error)
        }
    }

    /// Run prediction on the latest 60 Vision hand-pose frames.
    func predict(_ pixelBuffer: CVPixelBuffer) async throws -> SignPrediction {
        if model == nil {
            try await loadModel()
        }
        guard let model else { throw InferenceError.modelNotFound }

        guard let poseFrame = try extractPoseFrame(from: pixelBuffer) else {
            return SignPrediction(gestureLabel: "", confidence: 0)
        }

        poseFrames.append(poseFrame)
        if poseFrames.count > Self.frameCount {
            poseFrames.removeFirst(poseFrames.count - Self.frameCount)
        }

        guard poseFrames.count == Self.frameCount else {
            return SignPrediction(gestureLabel: "", confidence: 0)
        }

        let poses = try makePoseWindow()
        let input = try MLDictionaryFeatureProvider(dictionary: ["poses": poses])

        let output: MLFeatureProvider
        do {
            output = try await model.prediction(from: input)
        } catch {
            throw InferenceError.predictionFailed(error)
        }

        let rawOutput = extractProbabilities(from: output)
        let label = output.featureValue(for: "label")?.stringValue
            ?? rawOutput.max(by: { $0.value < $1.value })?.key
            ?? "unknown"
        let confidence = rawOutput[label]
            ?? rawOutput.max(by: { $0.value < $1.value })?.value
            ?? 0

        return SignPrediction(
            gestureLabel: label,
            confidence: confidence,
            rawOutput: rawOutput
        )
    }

    func reset() {
        poseFrames.removeAll()
    }

    private func extractPoseFrame(from pixelBuffer: CVPixelBuffer) throws -> [Double]? {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )
        try handler.perform([request])

        guard let observation = request.results?.first else { return nil }
        let points = try observation.recognizedPoints(.all)

        return jointNames.flatMap { jointName -> [Double] in
            guard let point = points[jointName], point.confidence > 0 else {
                return [0, 0, 0]
            }

            return [
                Double(point.location.x),
                Double(point.location.y),
                Double(point.confidence),
            ]
        }
    }

    private func makePoseWindow() throws -> MLMultiArray {
        let poses = try MLMultiArray(
            shape: [
                NSNumber(value: Self.frameCount),
                NSNumber(value: Self.channels),
                NSNumber(value: jointNames.count),
            ],
            dataType: .double
        )

        for frameIndex in 0..<Self.frameCount {
            let frame = poseFrames[frameIndex]
            for jointIndex in 0..<jointNames.count {
                for channelIndex in 0..<Self.channels {
                    let sourceIndex = jointIndex * Self.channels + channelIndex
                    poses[
                        [
                            NSNumber(value: frameIndex),
                            NSNumber(value: channelIndex),
                            NSNumber(value: jointIndex),
                        ]
                    ] = NSNumber(value: frame[sourceIndex])
                }
            }
        }

        return poses
    }

    private func extractProbabilities(from output: MLFeatureProvider) -> [String: Float] {
        guard let dictionary = output.featureValue(for: "labelProbabilities")?.dictionaryValue else {
            return [:]
        }

        var probabilities: [String: Float] = [:]
        for (key, value) in dictionary {
            guard let label = key as? String else { continue }
            probabilities[label] = value.floatValue
        }
        return probabilities
    }
}

// MARK: - Mock for testing

/// Returns a canned response after 300 ms — used for SwiftUI previews and unit tests.
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
            rawOutput: [
                stubLabel: stubConfidence, "thanks": 0.03, "please": 0.02,
            ]
        )
    }

    func reset() {}
}
