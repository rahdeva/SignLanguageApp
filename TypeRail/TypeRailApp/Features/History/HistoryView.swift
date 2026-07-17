//
//  HistoryView.swift
//  TypeRailApp
//

import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \TripRecord.startDate, order: .reverse) private var trips: [TripRecord]

    var body: some View {
        NavigationStack {
            if trips.isEmpty {
                ContentUnavailableView(
                    "Belum ada perjalanan",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Mulai perjalanan MRT untuk melihat riwayat")
                )
            } else {
                List(trips) { trip in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.startDate, style: .date)
                            .font(.headline)
                        HStack {
                            Text("Stasiun: \(trip.stationsCompleted)/13")
                            Spacer()
                            Text("Skor: \(trip.totalScore)")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                }
                .navigationTitle("Riwayat")
            }
        }
    }
}
