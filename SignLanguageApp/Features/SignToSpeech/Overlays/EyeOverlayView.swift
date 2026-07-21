//
//  EyeOverlayView.swift
//  SignLanguageApp
//
//  Created by rahdeva on 21/07/26.
//

import SwiftUI

struct EyeOverlayView: View {
    let leftEyePoints: [CGPoint]
    let rightEyePoints: [CGPoint]
    let isLeftClosed: Bool
    let isRightClosed: Bool

    var body: some View {
        Canvas { context, _ in
            drawEye(context: &context, points: leftEyePoints, isClosed: isLeftClosed)
            drawEye(context: &context, points: rightEyePoints, isClosed: isRightClosed)
        }
        .allowsHitTesting(false)
    }

    private func drawEye(context: inout GraphicsContext, points: [CGPoint], isClosed: Bool) {
        guard !points.isEmpty else { return }

        // 1. Draw Eye Landmark Contour Loop
        var path = Path()
        path.move(to: points[0])
        for p in points.dropFirst() {
            path.addLine(to: p)
        }
        path.closeSubpath()

        let strokeColor: Color = isClosed ? .orange : .cyan
        let glowColor: Color = isClosed ? .red.opacity(0.4) : .green.opacity(0.4)

        // Outer glow
        context.stroke(
            path,
            with: .color(glowColor),
            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        )
        // Inner crisp stroke
        context.stroke(
            path,
            with: .color(strokeColor),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        )

        // 2. Draw Landmark Dots
        for p in points {
            let radius: CGFloat = isClosed ? 3.5 : 2.5
            let dotColor: Color = isClosed ? .yellow : .white
            let rect = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(dotColor))
            context.stroke(Path(ellipseIn: rect), with: .color(.black.opacity(0.6)), style: StrokeStyle(lineWidth: 1))
        }
    }
}
