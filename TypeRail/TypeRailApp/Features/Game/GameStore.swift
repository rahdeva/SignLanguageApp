//
//  GameStore.swift
//  TypeRailApp
//

import Combine
import CoreLocation
import Foundation
import Observation

@Observable
@MainActor
final class GameStore {
    // MARK: - Game State
    var phase: GamePhase = .idle
    var currentStationIndex: Int = 0
    var score: Int = 0
    var combo: Int = 0
    var comboMultiplier: Double = 1.0
    var speedRatio: Double = 0.0 // 0.0–1.0
    var errorsInCurrentSegment: Int = 0
    var totalErrors: Int = 0
    var isTunnel: Bool = false
    var trainPosition: CLLocationCoordinate2D = RouteService.startStation.coordinate
    var cameraHeading: CLLocationDirection = 0
    var cameraDistance: CLLocationDistance = 500
    var cameraPitch: CGFloat = 60
    var stationProgress: Double = 0.0 // 0.0–1.0 within current segment
    var showLookAround: Bool = false
    var tripStartTime: Date = .now
    var lastTypingTime: Date = .now

    // MARK: - Computed
    var currentStation: MRTStation { RouteService.route.stations[currentStationIndex] }
    var nextStation: MRTStation? { RouteService.nextStation(after: currentStationIndex) }
    var isLastStation: Bool { currentStationIndex >= RouteService.route.totalStations - 1 }
    var stationsCompleted: Int { currentStationIndex }
    var totalStations: Int { RouteService.route.totalStations }

    // MARK: - Dependencies
    nonisolated let haptics = HapticEngine()

    // MARK: - Actions
    func startTrip() {
        phase = .traveling
        currentStationIndex = 0
        score = 0
        combo = 0
        comboMultiplier = 1.0
        speedRatio = 0.0
        totalErrors = 0
        trainPosition = RouteService.startStation.coordinate
        stationProgress = 0.0
        tripStartTime = .now
        Task { await haptics.start() }
    }

    /// Called when a correct character is typed.
    func onCorrectChar() {
        speedRatio = min(1.0, speedRatio + 0.05)
        stationProgress = min(1.0, stationProgress + 0.02)
        updateTrainPosition()
        Task { await haptics.play(.correctChar) }
    }

    /// Called when a wrong character is typed.
    func onWrongChar() {
        errorsInCurrentSegment += 1
        totalErrors += 1
        speedRatio = max(0.1, speedRatio - 0.2)
        phase = .slowed
        Task { await haptics.play(.wrongChar) }
        // Cooldown: resume after 300ms
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            phase = .traveling
        }
    }

    /// Called when the player finishes typing the station name.
    func onStationTypingComplete(result: TypingResult) {
        if result.errors > 0 {
            combo = 0
            comboMultiplier = 1.0
        } else {
            combo += 1
            comboMultiplier = TypingEngine.nextCombo(currentErrors: result.errors, previousMultiplier: comboMultiplier)
        }

        let points = TypingEngine.score(for: result, comboMultiplier: comboMultiplier, timeBonus: speedRatio > 0.5)
        score += points

        if result.errors == 0 {
            Task { await haptics.play(.perfectAccuracy) }
        }
        if comboMultiplier >= 3 {
            Task { await haptics.play(.comboMilestone) }
        }
    }

    /// Called when the train arrives at the next station.
    func onArriveAtStation() {
        phase = .docked
        Task { await haptics.play(.arrivingStation) }
        Task { try? await Task.sleep(nanoseconds: 500_000_000)
            await haptics.play(.doorsOpen)
        }
    }

    func proceedToNextStation() {
        guard !isLastStation else {
            phase = .finished
            return
        }
        currentStationIndex += 1
        errorsInCurrentSegment = 0
        stationProgress = 0.0
        speedRatio = 0.0
        phase = .traveling
        Task { await haptics.play(.doorsClose) }
    }

    func exploreStation() {
        phase = .exploring
        showLookAround = true
    }

    func dismissExploration() {
        showLookAround = false
        phase = .docked
    }

    /// Simulate tunnel for segments where tunnel is known (near Senayan–Istora).
    func updateTunnelState(at coordinate: CLLocationCoordinate2D) {
        // Simplified tunnel zone detection: constant region
        let tunnelZoneLatitudes: ClosedRange<Double> = (-6.228)...(-6.212)
        let tunnelZoneLongitudes: ClosedRange<Double> = (106.795)...(106.810)
        let wasTunnel = isTunnel
        isTunnel = tunnelZoneLatitudes.contains(coordinate.latitude)
            && tunnelZoneLongitudes.contains(coordinate.longitude)

        if isTunnel, !wasTunnel {
            Task { await haptics.play(.tunnel) }
        } else if !isTunnel, wasTunnel {
            Task { await haptics.play(.exitingTunnel) }
        }
    }

    func finishTrip() {
        phase = .finished
    }

    // MARK: - Private
    private func updateTrainPosition() {
        guard let next = nextStation else { return }
        let pos = TrainAnimationService.position(
            from: currentStation.coordinate,
            to: next.coordinate,
            progress: stationProgress,
            route: RouteService.route
        )
        trainPosition = pos

        let heading = CameraService.bearing(from: currentStation.coordinate, to: next.coordinate)
        cameraHeading = heading

        let delta = abs(CameraService.bearing(from: trainPosition, to: next.coordinate) - heading)
        let cam = CameraService.computeCamera(
            trainPosition: trainPosition,
            from: currentStation.coordinate,
            to: next.coordinate,
            speedRatio: speedRatio,
            isTunnel: isTunnel,
            bearingDelta: delta
        )
        cameraDistance = cam.distance
        cameraPitch = cam.pitch

        updateTunnelState(at: trainPosition)

        // Auto-arrive when progress > 95% (guard prevents re-fire)
        if stationProgress >= 0.95, phase != .docked {
            onArriveAtStation()
        }
    }
}
