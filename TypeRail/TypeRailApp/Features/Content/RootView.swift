//
//  RootView.swift
//  TypeRailApp
//

import SwiftUI

/// Root view — presents game screen, history, and settings tabs.
struct RootView: View {
    var body: some View {
        TabView {
            GameScreen()
                .tabItem {
                    Label("Game", systemImage: "tram.fill")
                }

            HistoryView()
                .tabItem {
                    Label("Riwayat", systemImage: "clock.arrow.circlepath")
                }

            SettingsView()
                .tabItem {
                    Label("Pengaturan", systemImage: "gearshape")
                }
        }
    }
}
