//
//  MRTStation.swift
//  TypeRailApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import CoreLocation

/// A single MRT Jakarta station with name and geographic coordinate.
struct MRTStation: Identifiable, Equatable, Sendable {
    /// Zero-based order index (0 = Lebak Bulus, 12 = Bundaran HI).
    let id: Int
    /// Display name for typing target e.g. "Lebak Bulus", "Bundaran HI".
    let name: String
    /// The station's geographic coordinate on the MRT route.
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: MRTStation, rhs: MRTStation) -> Bool {
        lhs.id == rhs.id
    }
}
