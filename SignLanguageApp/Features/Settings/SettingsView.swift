//
//  SettingsView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftUI
import UIKit

/// Settings tab — onboarding toggle, language pickers, permissions link, team info, version.
struct SettingsView: View {
    @Environment(AppStore.self) private var appStore
    @State private var hasSeenOnboarding = UserDefaults.standard.bool(
        forKey: "hasSeenOnboarding"
    )

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - General
                Section {
                    Toggle(isOn: $hasSeenOnboarding) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.onboarding.toggle", tableName: "Localizable")
                                .font(.body)
                            Text("settings.onboarding.description", tableName: "Localizable")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: hasSeenOnboarding) { _, newValue in
                        UserDefaults.standard.set(
                            !newValue,
                            forKey: "hasSeenOnboarding"
                        )
                    }
                } header: {
                    Text("settings.section.general", tableName: "Localizable")
                }

                // MARK: - Language
                @Bindable var settings = appStore.languageSettings
                Section {
                    LanguagePickerRow(
                        titleKey: "settings.language.app",
                        selection: $settings.appLanguage
                    )
                } header: {
                    Text("settings.section.language", tableName: "Localizable")
                }

                // MARK: - Privacy
                Section {
                    Link(
                        destination: URL(string: UIApplication.openSettingsURLString)!
                    ) {
                        Label(
                            LocalizedStringKey("settings.privacy.permissions"),
                            systemImage: "hand.raised.fill"
                        )
                    }
                } header: {
                    Text("settings.section.privacy", tableName: "Localizable")
                } footer: {
                    Text("settings.privacy.footer", tableName: "Localizable")
                }

                // MARK: - Team
                Section {
                    NavigationLink {
                        AboutTeamView()
                    } label: {
                        Text("settings.team.about", tableName: "Localizable")
                    }
                } header: {
                    Text("settings.section.team", tableName: "Localizable")
                }

                // MARK: - Version
                Section {
                    HStack {
                        Text("settings.version", tableName: "Localizable")
                        Spacer()
                        Text(
                            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(
                Text("settings.title", tableName: "Localizable")
            )
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppStore())
}

