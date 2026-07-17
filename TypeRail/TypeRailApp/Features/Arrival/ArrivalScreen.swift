//
//  ArrivalScreen.swift
//  TypeRailApp
//

import MapKit
import SwiftUI

struct ArrivalScreen: View {
    let station: MRTStation
    let store: GameStore
    @State private var lookAroundScene: MKLookAroundScene?
    @State private var isLookingAround = false

    var body: some View {
        VStack(spacing: 16) {
            Text("✅ Tiba di \(station.name)!")
                .font(.title.bold())

            HStack(spacing: 20) {
                Label("+\(store.score)", systemImage: "star.fill")
                Label("\u{00d7}\(String(format: "%.1f", store.comboMultiplier))", systemImage: "flame.fill")
            }

            // Look Around Preview
            if let scene = lookAroundScene {
                LookAroundPreview(initialScene: scene)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.secondary.opacity(0.2))
                    .frame(height: 250)
                    .overlay {
                        VStack {
                            Image(systemName: "binoculars")
                                .font(.largeTitle)
                            Text("Street view tidak tersedia")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)
            }

            HStack(spacing: 16) {
                Button("\u{1f50d} Explore") {
                    isLookingAround = true
                }
                .buttonStyle(.bordered)

                if store.isLastStation {
                    Button("\u{1f3c1} Selesai") {
                        store.finishTrip()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("\u{1f683} Lanjut ke \(store.nextStation?.name ?? "")") {
                        store.proceedToNextStation()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .task {
            await loadLookAroundScene()
        }
        .lookAroundViewer(isPresented: $isLookingAround, initialScene: lookAroundScene)
    }

    private func loadLookAroundScene() async {
        let request = MKLookAroundSceneRequest(coordinate: station.coordinate)
        do {
            lookAroundScene = try await request.scene
        } catch {
            // Scene unavailable — show fallback
        }
    }
}
