//
//  SignLanguageInferencer.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

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

protocol SignLanguageInferencing: Actor, Sendable {
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
            input = try MLDictionaryFeatureProvider(dictionary: ["image": value])
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
