//
//  TrainAnimationService.swift
//  TypeRailApp
//

import CoreLocation
import Foundation
import MapKit

/// Computes the train position along a polyline between two stations.
enum TrainAnimationService {
    /// Returns the interpolated coordinate at `progress` (0.0–1.0) between two coordinates on the route polyline.
    static func position(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        progress: Double,
        route: MRTRoute
    ) -> CLLocationCoordinate2D {
        let clampedProgress = max(0, min(1, progress))

        // Find the segment indices within the polyline
        let sourceIndex = findClosestIndex(to: source, in: route.polylinePoints)
        let destIndex = findClosestIndex(to: destination, in: route.polylinePoints)

        guard sourceIndex < destIndex else { return source }

        let segmentCount = destIndex - sourceIndex
        let targetSegment = sourceIndex + Int(Double(segmentCount) * clampedProgress)
        let clampedSegment = min(targetSegment, destIndex - 1)

        let segmentProgress = (Double(targetSegment) - Double(sourceIndex) - Double(segmentCount) * clampedProgress)
            .magnitude

        guard clampedSegment + 1 < route.polylinePoints.count else {
            return route.polylinePoints[clampedSegment]
        }

        let from = route.polylinePoints[clampedSegment]
        let to = route.polylinePoints[clampedSegment + 1]

        return CLLocationCoordinate2D(
            latitude: from.latitude + (to.latitude - from.latitude) * (1 - segmentProgress),
            longitude: from.longitude + (to.longitude - from.longitude) * (1 - segmentProgress)
        )
    }

    private static func findClosestIndex(to coordinate: CLLocationCoordinate2D, in points: [CLLocationCoordinate2D]) -> Int {
        var minDist = Double.infinity
        var minIdx = 0
        for (index, point) in points.enumerated() {
            let dist = pow(point.latitude - coordinate.latitude, 2) + pow(point.longitude - coordinate.longitude, 2)
            if dist < minDist {
                minDist = dist
                minIdx = index
            }
        }
        return minIdx
    }
}
