//
//  GamePersistence.swift
//  TypeRailApp
//

import Foundation
import SwiftData

/// Manages SwiftData operations for trip records.
@MainActor
final class GamePersistence {
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(for: TripRecord.self)
    }

    func saveTrip(_ record: TripRecord) {
        container.mainContext.insert(record)
        try? container.mainContext.save()
    }

    func loadAllTrips() -> [TripRecord] {
        let descriptor = FetchDescriptor<TripRecord>(sortBy: [.init(\.startDate, order: .reverse)])
        return (try? container.mainContext.fetch(descriptor)) ?? []
    }

    func deleteAll() {
        try? container.mainContext.delete(model: TripRecord.self)
    }
}
