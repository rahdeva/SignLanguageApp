//
//  CameraPreviewSource.swift
//  StellaApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import AVFoundation
import UIKit

// MARK: - Preview protocols (Apple AVCam pattern)

/// Object that can provide a capture session to a preview target.
protocol PreviewSource: AnyObject {
    func connect(to target: any PreviewTarget)
}

/// Object that can receive and display a capture session (e.g. `AVCaptureVideoPreviewLayer`).
protocol PreviewTarget: AnyObject {
    func setSession(_ session: AVCaptureSession)
}

// MARK: - UIKit preview view

/// UIView whose backing layer is `AVCaptureVideoPreviewLayer`.
final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

/// Conformance that wires the session into the preview layer.
extension CameraPreviewUIView: PreviewTarget {
    func setSession(_ session: AVCaptureSession) {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }
}
