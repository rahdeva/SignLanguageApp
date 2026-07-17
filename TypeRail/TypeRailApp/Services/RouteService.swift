//
//  RouteService.swift
//  TypeRailApp
//

import CoreLocation
import Foundation

/// Single source of truth for MRT Jakarta Fase 1 station data and route polyline.
enum RouteService {
    // Koordinat akurat dari Wikipedia + OpenStreetMap (diverifikasi per stasiun, Juli 2025).
    // Urutan: Lebak Bulus (selatan) → Bundaran HI (utara).
    private static let stationList: [MRTStation] = [
        .init(id: 0,  name: "Lebak Bulus",     coordinate: .init(latitude: -6.28923, longitude: 106.77488)),
        .init(id: 1,  name: "Fatmawati",       coordinate: .init(latitude: -6.29243, longitude: 106.79247)),
        .init(id: 2,  name: "Cipete Raya",     coordinate: .init(latitude: -6.27740, longitude: 106.79750)),
        .init(id: 3,  name: "Haji Nawi",       coordinate: .init(latitude: -6.26680, longitude: 106.79732)),
        .init(id: 4,  name: "Blok A",          coordinate: .init(latitude: -6.25558, longitude: 106.79713)),
        .init(id: 5,  name: "Blok M",          coordinate: .init(latitude: -6.24453, longitude: 106.79821)),
        .init(id: 6,  name: "ASEAN",           coordinate: .init(latitude: -6.23909, longitude: 106.79860)),
        .init(id: 7,  name: "Senayan",         coordinate: .init(latitude: -6.22668, longitude: 106.80246)),
        .init(id: 8,  name: "Istora",          coordinate: .init(latitude: -6.22233, longitude: 106.80857)),
        .init(id: 9,  name: "Bendungan Hilir", coordinate: .init(latitude: -6.21545, longitude: 106.81732)),
        .init(id: 10, name: "Setiabudi",       coordinate: .init(latitude: -6.20910, longitude: 106.82170)),
        .init(id: 11, name: "Dukuh Atas",      coordinate: .init(latitude: -6.20079, longitude: 106.82275)),
        .init(id: 12, name: "Bundaran HI",     coordinate: .init(latitude: -6.19341, longitude: 106.82286)),
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
