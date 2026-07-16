//
//  CameraPreviewSource.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import AVFoundation
import UIKit

// MARK: - Preview protocols (Apple AVCam pattern)

protocol PreviewSource: AnyObject {
    func connect(to target: any PreviewTarget)
}

protocol PreviewTarget: AnyObject {
    func setSession(_ session: AVCaptureSession)
}

// MARK: - UIKit preview view

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

extension CameraPreviewUIView: PreviewTarget {
    func setSession(_ session: AVCaptureSession) {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }
}
