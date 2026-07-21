//
//  SignLanguageApp.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftData
import SwiftUI

/// App entry point. Root scene connects `AppStore` to the view hierarchy.
@main
struct SignLanguageApp: App {
    let container: ModelContainer = {
        guard let container = try? ModelContainer(for: ChatSession.self, ChatMessage.self) else {
            fatalError("Failed to create ModelContainer")
        }
        return container
    }()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
