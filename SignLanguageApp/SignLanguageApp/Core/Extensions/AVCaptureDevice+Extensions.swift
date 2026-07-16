//
//  AVCaptureDevice+Extensions.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import AVFoundation
import OSLog

extension AVCaptureDevice {
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

    static var defaultMicrophone: AVCaptureDevice? {
        .default(for: .audio)
    }
}
