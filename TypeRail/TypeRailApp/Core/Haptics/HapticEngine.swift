//
//  HapticEngine.swift
//  TypeRailApp
//

import CoreHaptics
import Foundation
import os

/// Actor-based wrapper around CHHapticEngine for thread-safe haptic playback.
actor HapticEngine {
    private var engine: CHHapticEngine?
    private let logger = AppLogger(for: HapticEngine.self)
    private(set) var supportsHaptics: Bool = false

    func start() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            supportsHaptics = false
            logger.warning("Device does not support haptics")
            return
        }
        supportsHaptics = true
        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                guard let self else { return }
                Task { await self.restart() }
            }
            engine?.stoppedHandler = { [weak self] reason in
                guard let self else { return }
                Task { await self.logger.warning("Haptic engine stopped: \(reason.rawValue)") }
            }
            try engine?.start()
        } catch {
            logger.error("Failed to start haptic engine: \(error)")
        }
    }

    private func restart() {
        do {
            try engine?.start()
        } catch {
            logger.error("Failed to restart haptic engine: \(error)")
        }
    }

    func play(_ event: HapticEvent) {
        guard supportsHaptics, let engine else { return }
        let (events, _) = HapticPatterns.parameters(for: event)
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            logger.error("Haptic play failed: \(error)")
        }
    }

    func stop() {
        engine?.stop(completionHandler: nil)
    }
}
