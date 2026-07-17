//
//  CameraService.swift
//  TypeRailApp
//

import CoreLocation
import Foundation
import MapKit

/// Computes camera parameters for train-following perspective.
enum CameraService {
    struct CameraState: Sendable {
        let center: CLLocationCoordinate2D
        let distance: CLLocationDistance
        let heading: CLLocationDirection
        let pitch: CGFloat
    }

    /// Compute camera state given train position, current segment, and speed ratio.
    static func computeCamera(
        trainPosition: CLLocationCoordinate2D,
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        speedRatio: Double, // 0.0–1.0
        isTunnel: Bool,
        bearingDelta: Double // degrees
    ) -> CameraState {
        let baseDistance: CLLocationDistance = 500
        let adjustedDistance = max(200, min(800, baseDistance - speedRatio * 300))

        let heading = bearing(from: source, to: destination)

        let pitch: CGFloat
        if isTunnel {
            pitch = 90
        } else if bearingDelta > 30 {
            pitch = 75
        } else if speedRatio > 0.8 {
            pitch = 45
        } else {
            pitch = 60
        }

        return CameraState(
            center: trainPosition,
            distance: adjustedDistance,
            heading: heading,
            pitch: pitch
        )
    }

    /// Calculates bearing (degrees from true north) between two coordinates.
    static func bearing(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = source.latitude.radians
        let lon1 = source.longitude.radians
        let lat2 = destination.latitude.radians
        let lon2 = destination.longitude.radians

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearingRad = atan2(y, x)
        let bearingDeg = bearingRad.degrees
        return (bearingDeg + 360).truncatingRemainder(dividingBy: 360)
    }
}

private extension Double {
    var radians: Self { self * .pi / 180 }
    var degrees: Self { self * 180 / .pi }
}
