//
//  SettingsView.swift
//  TypeRailApp
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                Section("Data") {
                    Button("Hapus Semua Riwayat", role: .destructive) {
                        try? modelContext.delete(model: TripRecord.self)
                    }
                }

                Section("Tentang") {
                    LabeledContent("Versi", value: "1.0")
                    LabeledContent("Tim", value: "Dewa Ayam")
                }
            }
            .navigationTitle("Pengaturan")
        }
    }
}
