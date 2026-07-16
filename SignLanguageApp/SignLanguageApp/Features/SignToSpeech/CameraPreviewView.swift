import AVFoundation
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let source: any PreviewSource

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        source.connect(to: view)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}
