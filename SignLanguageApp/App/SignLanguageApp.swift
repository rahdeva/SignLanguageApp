//
//  SignLanguageApp.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftUI
import SwiftData

/// App entry point. Root scene connects `AppStore` and SwiftData modelContainer to the view hierarchy.
@main
struct SignLanguageApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: PracticeHistoryItem.self)
    }
}
