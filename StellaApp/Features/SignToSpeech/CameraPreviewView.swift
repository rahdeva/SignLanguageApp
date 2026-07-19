//
//  CameraPreviewView.swift
//  StellaApp
//
//  Created by rahdeva on 16/07/26.
//

import AVFoundation
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let isFrontCamera: Bool
    // Weak reference so CameraManager can call layerPointConverted on the live layer
    weak var cameraManager: CameraManager?

    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        // Register the live layer into CameraManager so captureOutput can use layerPointConverted
        cameraManager?.previewLayer = view.videoPreviewLayer
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        if uiView.videoPreviewLayer.session != session {
            uiView.videoPreviewLayer.session = session
        }
        // Keep the layer reference fresh after camera flips
        cameraManager?.previewLayer = uiView.videoPreviewLayer

        // Mirror the preview for the front camera so it looks like a selfie mirror,
        // but leave videoDataOutput unmirrored so Vision/CoreML get raw coordinates.
        if let connection = uiView.videoPreviewLayer.connection {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90.0) {
                    connection.videoRotationAngle = 90.0
                }
            } else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            if connection.isVideoMirroringSupported {
                // Must disable automatic mirroring before setting it manually,
                // otherwise AVFoundation throws NSInvalidArgumentException.
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = isFrontCamera
            }
        }
    }
}
