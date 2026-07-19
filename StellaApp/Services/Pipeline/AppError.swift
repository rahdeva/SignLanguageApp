//
//  AppError.swift
//  StellaApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import Foundation

/// Unified error type used across the app for user-facing error messages.
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
        case .inferenceFailed(let detail):
            "Sign language recognition failed: \(detail)"
        case .permissionDenied(let feature): "Permission denied for \(feature)"
        case .unknown(let detail): "An error occurred: \(detail)"
        }
    }
}
