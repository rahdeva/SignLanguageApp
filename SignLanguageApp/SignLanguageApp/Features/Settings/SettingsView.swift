//
//  SettingsView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftUI
import UIKit

/// Settings tab — onboarding toggle, permissions link, team info, version.
struct SettingsView: View {
    @State private var hasSeenOnboarding = UserDefaults.standard.bool(
        forKey: "hasSeenOnboarding"
    )

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $hasSeenOnboarding) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Onboarding on Launch")
                                .font(AppStyle.Font.body)
                            Text(
                                "Replay the introduction screens next time you open the app"
                            )
                            .font(AppStyle.Font.caption)
                            .foregroundStyle(AppStyle.Color.secondaryText)
                        }
                    }
                    .onChange(of: hasSeenOnboarding) { _, newValue in
                        UserDefaults.standard.set(
                            !newValue,
                            forKey: "hasSeenOnboarding"
                        )
                    }
                } header: {
                    Text("General")
                }

                Section {
                    Link(
                        destination: URL(
                            string: UIApplication.openSettingsURLString
                        )!
                    ) {
                        Label(
                            "App Permissions",
                            systemImage: "hand.raised.fill"
                        )
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text(
                        "Camera, microphone, and speech recognition permissions can be changed in system Settings."
                    )
                }

                Section {
                    NavigationLink {
                        AboutTeamView()
                    } label: {
                        Text("About Team")
                    }
                } header: {
                    Text("Team")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(
                            Bundle.main.infoDictionary?[
                                "CFBundleShortVersionString"
                            ] as? String ?? "1.0"
                        )
                        .foregroundStyle(AppStyle.Color.secondaryText)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
