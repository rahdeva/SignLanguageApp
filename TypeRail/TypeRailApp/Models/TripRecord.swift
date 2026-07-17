//
//  TripRecord.swift
//  TypeRailApp
//

import Foundation
import SwiftData

/// Persisted model for a completed trip.
@Model
final class TripRecord {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var stationsCompleted: Int
    var totalScore: Int
    var averageAccuracy: Double
    var topCombo: Int
    var totalErrors: Int

    init(
        id: UUID = UUID(),
        startDate: Date = .now,
        endDate: Date? = nil,
        stationsCompleted: Int = 0,
        totalScore: Int = 0,
        averageAccuracy: Double = 0,
        topCombo: Int = 0,
        totalErrors: Int = 0
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.stationsCompleted = stationsCompleted
        self.totalScore = totalScore
        self.averageAccuracy = averageAccuracy
        self.topCombo = topCombo
        self.totalErrors = totalErrors
    }
}
