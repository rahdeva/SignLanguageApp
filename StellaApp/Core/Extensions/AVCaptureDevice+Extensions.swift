//
//  AVCaptureDevice+Extensions.swift
//  StellaApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import AVFoundation
import OSLog

/// Convenience accessors for the default camera and microphone.
extension AVCaptureDevice {
    /// Preferred back/front camera. Falls back from external → wide-angle.
    static var defaultCamera: AVCaptureDevice {
        let device: AVCaptureDevice? =
            .default(.external, for: .video, position: .unspecified)
            ?? .default(.builtInWideAngleCamera, for: .video, position: .front)
        guard let camera = device else {
            AppLogger.default.error("No camera device found")
            return .default(
                .builtInWideAngleCamera,
                for: .video,
                position: .front
            )!
        }
        return camera
    }

    /// Default audio capture device (built-in mic).
    static var defaultMicrophone: AVCaptureDevice? {
        .default(for: .audio)
    }
}
