//
//  HapticManager.swift
//  Stella
//
//  Created by Antigravity on 23/07/26.
//

import CoreHaptics
import SwiftUI

/// Plays custom haptic patterns via Core Haptics, with a UIKit fallback for
/// devices that don't support the haptic engine (older iPhones, iPad, Simulator).
final class HapticManager {
    static let shared = HapticManager()

    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    private init() {
        prepareEngine()
    }

    private func prepareEngine() {
        guard supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            // Restart the engine if the system stops it (e.g. after an interruption).
            engine?.stoppedHandler = { [weak self] _ in
                try? self?.engine?.start()
            }
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            try engine?.start()
        } catch {
            print("⚠️ Haptic engine failed to start: \(error)")
            engine = nil
        }
    }

    /// A celebratory two-tap pattern (soft tap then a stronger, sharper tap)
    /// played when the learner successfully performs the target sign.
    func playSuccess() {
        guard supportsHaptics, let engine else {
            // Fallback for unsupported hardware.
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ],
                relativeTime: 0.12
            )
        ]

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("⚠️ Failed to play success haptic: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
