//
//  CameraPreviewView.swift
//  SignLanguageApp
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
        weak var cameraManager: CameraManager?

        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            cameraManager?.updateROI()
            cameraManager?.configurePreviewLayerOrientation()
        }
    }

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.cameraManager = cameraManager
        // Register the live layer into CameraManager so captureOutput can use layerPointConverted
        cameraManager?.previewLayer = view.videoPreviewLayer
        cameraManager?.updateROI()
        cameraManager?.configurePreviewLayerOrientation()
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        if uiView.videoPreviewLayer.session != session {
            uiView.videoPreviewLayer.session = session
        }
        uiView.cameraManager = cameraManager
        // Keep the layer reference fresh after camera flips
        cameraManager?.previewLayer = uiView.videoPreviewLayer
        cameraManager?.updateROI()
        cameraManager?.configurePreviewLayerOrientation()
    }
}
