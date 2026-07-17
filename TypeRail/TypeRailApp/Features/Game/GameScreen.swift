//
//  GameScreen.swift
//  TypeRailApp
//

import MapKit
import SwiftUI

struct GameScreen: View {
    @State private var gameStore = GameStore()
    @State private var typedText: String = ""
    @FocusState private var isTypingFocused: Bool

    private let typingCooldown: TimeInterval = 0.3
    @State private var lastTypingTimestamp: Date = .now

    var body: some View {
        ZStack(alignment: .top) {
            // Map
            MapController(
                route: RouteService.route,
                trainCoordinate: gameStore.trainPosition,
                cameraHeading: gameStore.cameraHeading,
                cameraDistance: gameStore.cameraDistance,
                cameraPitch: gameStore.cameraPitch
            )
            .ignoresSafeArea(edges: .top)
            .frame(height: UIScreen.main.bounds.height * 0.55)

            // HUD overlay
            HUDView(gameStore: gameStore)

            // Bottom typing panel
            if gameStore.phase == .traveling || gameStore.phase == .slowed {
                VStack {
                    Spacer()
                    TypingPanelView(
                        currentStation: gameStore.currentStation,
                        nextStation: gameStore.nextStation,
                        typedText: $typedText,
                        speedRatio: gameStore.speedRatio,
                        onType: handleTyping
                    )
                }
            }

            // Start button (idle)
            if gameStore.phase == .idle {
                VStack {
                    Spacer()
                    Button("Mulai Perjalanan") {
                        gameStore.startTrip()
                        isTypingFocused = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom, 40)
                }
            }
        }
        .fullScreenCover(isPresented: .init(
            get: { gameStore.phase == .docked || gameStore.phase == .exploring },
            set: { if !$0 { gameStore.dismissExploration() } }
        )) {
            ArrivalScreen(
                station: gameStore.currentStation,
                store: gameStore
            )
        }
        .fullScreenCover(isPresented: .init(
            get: { gameStore.phase == .finished },
            set: { _ in }
        )) {
            TripSummaryView(store: gameStore)
        }
    }

    private func handleTyping(_ text: String) {
        guard let target = gameStore.nextStation else { return }
        let now = Date()
        guard now.timeIntervalSince(lastTypingTimestamp) >= typingCooldown else { return }
        lastTypingTimestamp = now

        let result = TypingEngine.validate(typed: text, target: target.name)
        if Double(result.correctChars) > gameStore.stationProgress {
            gameStore.onCorrectChar()
        }
        if result.errors > gameStore.errorsInCurrentSegment {
            gameStore.onWrongChar()
        }

        // Check if station name fully typed
        if text.lowercased().trimmingCharacters(in: .whitespaces) == target.name.lowercased() {
            gameStore.onStationTypingComplete(result: result)
            typedText = ""
            gameStore.stationProgress = 0.95 // Trigger auto-arrive
        }
    }
}

// MARK: - HUD
private struct HUDView: View {
    let gameStore: GameStore

    var body: some View {
        HStack {
            Text("Score: \(gameStore.score)")
                .font(.headline)
            Spacer()
            if gameStore.phase == .traveling || gameStore.phase == .slowed {
                Text("Combo \u{00d7}\(String(format: "%.1f", gameStore.comboMultiplier))")
                    .font(.caption)
                    .foregroundColor(gameStore.comboMultiplier > 1 ? .yellow : .white)
                Text("\(gameStore.stationsCompleted)/\(gameStore.totalStations)")
                    .font(.caption)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

// MARK: - Typing Panel
private struct TypingPanelView: View {
    let currentStation: MRTStation
    let nextStation: MRTStation?
    @Binding var typedText: String
    let speedRatio: Double
    let onType: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "tram.fill")
                Text(currentStation.name)
                Image(systemName: "arrow.right")
                if let next = nextStation {
                    Text(next.name)
                        .fontWeight(.bold)
                }
            }
            .font(.subheadline)

            TextField("Ketik nama stasiun tujuan...", text: $typedText)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal)
                .onChange(of: typedText) { _, newValue in
                    onType(newValue)
                }

            // Speed bar
            ProgressView(value: speedRatio)
                .tint(speedRatio > 0.7 ? .green : speedRatio > 0.3 ? .orange : .red)
                .padding(.horizontal)

            if let next = nextStation {
                SuggestionView(typed: typedText, target: next.name)
            }
        }
        .padding()
        .background(.regularMaterial)
    }
}

// MARK: - Suggestion
private struct SuggestionView: View {
    let typed: String
    let target: String

    var suggestion: String {
        guard !typed.isEmpty, !target.isEmpty else { return "" }
        guard typed.count < target.count else { return "" }
        let start = target.index(target.startIndex, offsetBy: typed.count)
        return String(target[start...])
    }

    var body: some View {
        if !suggestion.isEmpty {
            HStack {
                Text(typed)
                    .foregroundColor(.green)
                    + Text(suggestion)
                    .foregroundColor(.secondary)
            }
            .font(.callout.monospaced())
        }
    }
}

// MARK: - Trip Summary
private struct TripSummaryView: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Perjalanan Selesai! \u{1f389}")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("Stasiun: \(store.stationsCompleted)/\(store.totalStations)")
                Text("Skor: \(store.score)")
                Text("Combo Tertinggi: \u{00d7}\(String(format: "%.1f", store.comboMultiplier))")
                Text("Kesalahan: \(store.totalErrors)")
            }

            Button("Perjalanan Baru") {
                store.startTrip()
            }
            .buttonStyle(.borderedProminent)

            Button("Kembali") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
