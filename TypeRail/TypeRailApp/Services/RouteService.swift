//
//  RouteService.swift
//  TypeRailApp
//

import CoreLocation
import Foundation

/// Single source of truth for MRT Jakarta Fase 1 station data and route polyline.
enum RouteService {
    private static let stationList: [MRTStation] = [
        .init(id: 0, name: "Lebak Bulus", coordinate: .init(latitude: -6.3100, longitude: 106.7800)),
        .init(id: 1, name: "Fatmawati", coordinate: .init(latitude: -6.2900, longitude: 106.7900)),
        .init(id: 2, name: "Cipete Raya", coordinate: .init(latitude: -6.2780, longitude: 106.7980)),
        .init(id: 3, name: "Haji Nawi", coordinate: .init(latitude: -6.2660, longitude: 106.8050)),
        .init(id: 4, name: "Blok A", coordinate: .init(latitude: -6.2520, longitude: 106.8100)),
        .init(id: 5, name: "Blok M", coordinate: .init(latitude: -6.2440, longitude: 106.7980)),
        .init(id: 6, name: "ASEAN", coordinate: .init(latitude: -6.2380, longitude: 106.7900)),
        .init(id: 7, name: "Senayan", coordinate: .init(latitude: -6.2250, longitude: 106.7960)),
        .init(id: 8, name: "Istora", coordinate: .init(latitude: -6.2150, longitude: 106.8080)),
        .init(id: 9, name: "Bendungan Hilir", coordinate: .init(latitude: -6.2080, longitude: 106.8180)),
        .init(id: 10, name: "Setiabudi", coordinate: .init(latitude: -6.2010, longitude: 106.8280)),
        .init(id: 11, name: "Dukuh Atas", coordinate: .init(latitude: -6.1940, longitude: 106.8350)),
        .init(id: 12, name: "Bundaran HI", coordinate: .init(latitude: -6.1850, longitude: 106.8180)),
    ]

    /// Waypoints along the physical rail trace between stations for smooth polyline.
    /// Currently uses station coordinates directly; can be extended with intermediate waypoints.
    private static let waypoints: [CLLocationCoordinate2D] = stationList.map(\.coordinate)

    /// The full MRT Jakarta Fase 1 route.
    static let route = MRTRoute(stations: stationList, polylinePoints: waypoints)

    /// Returns the station after `currentStationIndex`, or `nil` if already at the last station.
    static func nextStation(after index: Int) -> MRTStation? {
        route.station(at: index + 1)
    }

    /// The starting station for every trip (Lebak Bulus).
    static let startStation: MRTStation = stationList[0]
    /// The final station (Bundaran HI).
    static let endStation: MRTStation = stationList[12]
}
