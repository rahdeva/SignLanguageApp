//
//  BodyOverlayView.swift
//  SignLanguageApp
//
//  Created by rahdeva on 17/07/26.
//  Renders:
//    - Body skeleton  (17 joints, orange)
//    - Mouth contour  ( 8 points,  pink)
//  Points are already in AVCaptureVideoPreviewLayer pixel coords
//  (converted in CameraManager via layerPointConverted).
//

import SwiftUI
import Vision

struct BodyOverlayView: View {
    let skeleton: SkeletonPoints

    // ── Body skeleton connection chains ────────────────────────────────────────
    private let bodyChains: [[VNHumanBodyPoseObservation.JointName]] = [
        // Head arc
        [.leftEar, .leftEye, .nose, .rightEye, .rightEar],
        // Left arm
        [.leftShoulder, .leftElbow, .leftWrist],
        // Right arm
        [.rightShoulder, .rightElbow, .rightWrist],
        // Shoulder crossbar
        [.leftShoulder, .rightShoulder],
        // Left torso
        [.leftShoulder, .leftHip],
        // Right torso
        [.rightShoulder, .rightHip],
        // Hip crossbar
        [.leftHip, .rightHip],
        // Left leg
        [.leftHip, .leftKnee, .leftAnkle],
        // Right leg
        [.rightHip, .rightKnee, .rightAnkle]
    ]

    // Joints that get a larger dot
    private let keyJoints: Set<VNHumanBodyPoseObservation.JointName> = [
        .leftShoulder, .rightShoulder, .leftHip, .rightHip, .nose
    ]

    var body: some View {
        Canvas { context, _ in
            drawBodySkeleton(context: context)
            drawMouthContour(context: context)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Body Skeleton
    private func drawBodySkeleton(context: GraphicsContext) {
        let pts = skeleton.bodyPoints
        guard !pts.isEmpty else { return }

        // 1. Connection chains
        for chain in bodyChains {
            var path = Path()
            var isFirst = true
            for joint in chain {
                guard let p = pts[joint] else { continue }
                if isFirst { path.move(to: p); isFirst = false }
                else        { path.addLine(to: p) }
            }
            // Glow
            context.stroke(path,
                           with: .color(Color.orange.opacity(0.30)),
                           style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            // Core line
            context.stroke(path,
                           with: .color(.orange),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }

        // 2. Joint dots
        for (joint, p) in pts {
            let isKey    = keyJoints.contains(joint)
            let radius   : CGFloat = isKey ? 7.0 : 4.5
            let fillColor: Color   = isKey ? .orange : Color(hue: 0.10, saturation: 0.9, brightness: 1.0)

            let rect = CGRect(x: p.x - radius, y: p.y - radius,
                              width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(fillColor))
            context.stroke(Path(ellipseIn: rect),
                           with: .color(Color.black.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 1.5))
        }
    }

    // MARK: - Mouth Contour
    private func drawMouthContour(context: GraphicsContext) {
        // Filter zero-padding and require at least 2 real points
        let pts = skeleton.mouthPoints.filter { $0.x != 0 || $0.y != 0 }
        guard pts.count >= 2 else { return }

        // Build closed contour path
        var path = Path()
        path.move(to: pts[0])
        for p in pts.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()

        // Filled region
        context.fill(path, with: .color(Color.pink.opacity(0.22)))
        // Glow outline
        context.stroke(path,
                       with: .color(Color.pink.opacity(0.45)),
                       style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        // Core outline
        context.stroke(path,
                       with: .color(.pink),
                       style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

        // Landmark dots
        for p in pts {
            let r = CGFloat(3.5)
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(.pink))
            context.stroke(Path(ellipseIn: rect),
                           with: .color(Color.black.opacity(0.4)),
                           style: StrokeStyle(lineWidth: 1.0))
        }
    }
}
