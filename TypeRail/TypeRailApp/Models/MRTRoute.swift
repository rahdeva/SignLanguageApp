//
//  MRTRoute.swift
//  TypeRailApp
//

import MapKit

/// Describes the full MRT Jakarta Fase 1 route: stations + polyline waypoints.
struct MRTRoute: Sendable {
    let stations: [MRTStation]
    let polylinePoints: [CLLocationCoordinate2D]

    var totalStations: Int { stations.count }

    func station(at index: Int) -> MRTStation? {
        guard stations.indices.contains(index) else { return nil }
        return stations[index]
    }
}
