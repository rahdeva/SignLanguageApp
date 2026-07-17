//
//  TypeRailApp.swift
//  TypeRailApp
//

import SwiftUI
import SwiftData

@main
struct TypeRailApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: TripRecord.self)
    }
}
