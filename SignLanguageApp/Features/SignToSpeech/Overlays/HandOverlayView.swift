//
//  HandOverlayView.swift
//  SignLanguageApp
//
//  Created by rahdeva on 16/07/26.
//

import SwiftUI
import Vision

struct HandOverlayView: View {
    // Points are already in AVCaptureVideoPreviewLayer pixel coordinates,
    // converted via layerPointConverted(fromCaptureDevicePoint:) in CameraManager.
    // No manual scale / offset / mirror transform needed here.
    let handPoints: [VNHumanHandPoseObservation.JointName: CGPoint]

    private let fingerChains: [[VNHumanHandPoseObservation.JointName]] = [
        // Thumb
        [.wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip],
        // Index
        [.wrist, .indexMCP, .indexPIP, .indexDIP, .indexTip],
        // Middle
        [.wrist, .middleMCP, .middlePIP, .middleDIP, .middleTip],
        // Ring
        [.wrist, .ringMCP, .ringPIP, .ringDIP, .ringTip],
        // Little
        [.wrist, .littleMCP, .littlePIP, .littleDIP, .littleTip],
        // Knuckle arch
        [.indexMCP, .middleMCP, .ringMCP, .littleMCP]
    ]

    var body: some View {
        Canvas { context, _ in
            guard !handPoints.isEmpty else { return }

            // Points are already pixel coordinates in the preview layer.
            // We only need to look them up directly.
            func pt(for joint: VNHumanHandPoseObservation.JointName) -> CGPoint? {
                handPoints[joint]
            }

            // 1. Draw Skeleton Connection Chains
            for chain in fingerChains {
                var path = Path()
                var isFirst = true

                for joint in chain {
                    if let p = pt(for: joint) {
                        if isFirst {
                            path.move(to: p)
                            isFirst = false
                        } else {
                            path.addLine(to: p)
                        }
                    }
                }

                // Outer glow stroke
                context.stroke(path, with: .color(.cyan.opacity(0.35)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                // Inner crisp stroke
                context.stroke(path, with: .color(.cyan), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

            // 2. Draw Keypoint Dots
            for (joint, p) in handPoints {
                let isTip = [VNHumanHandPoseObservation.JointName.thumbTip, .indexTip, .middleTip, .ringTip, .littleTip].contains(joint)
                let isWrist = (joint == .wrist)
                let radius: CGFloat = isTip ? 6.5 : (isWrist ? 8.0 : 4.5)
                let dotColor: Color = isTip ? .yellow : (isWrist ? .orange : .white)

                let rect = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                context.stroke(Path(ellipseIn: rect), with: .color(.black.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5))
            }
        }
        .allowsHitTesting(false)
    }
}
