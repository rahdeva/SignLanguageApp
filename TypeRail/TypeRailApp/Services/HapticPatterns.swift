//
//  HapticPatterns.swift
//  TypeRailApp
//

import CoreHaptics
import Foundation

/// Event types that trigger haptic feedback.
enum HapticEvent: Sendable {
    case startAcceleration
    case cruising(speedRatio: Double)
    case highSpeed
    case enteringTurn
    case tunnel
    case exitingTunnel
    case arrivingStation
    case doorsOpen
    case doorsClose
    case correctChar
    case wrongChar
    case comboMilestone
    case perfectAccuracy
}

/// Factory that generates Core Haptics CHHapticPattern parameter arrays per HapticEvent.
enum HapticPatterns {
    static func parameters(for event: HapticEvent) -> ([CHHapticEvent], isContinuous: Bool) {
        switch event {
        case .startAcceleration:
            let ev = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.6),
                    .init(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0
            )
            return ([ev], false)

        case .cruising(let speedRatio):
            let intensity = Float(0.2 + speedRatio * 0.4)
            let ev = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: intensity),
                    .init(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: 0,
                duration: 0.5
            )
            return ([ev], true)

        case .highSpeed:
            let ev = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.6),
                    .init(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0,
                duration: 0.3
            )
            return ([ev], true)

        case .enteringTurn:
            let events = (0..<3).map { i in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.4 + Float(i) * 0.15),
                        .init(parameterID: .hapticSharpness, value: 0.3 + Float(i) * 0.25)
                    ],
                    relativeTime: TimeInterval(i) * 0.1
                )
            }
            return (events, false)

        case .tunnel:
            let ev = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.3),
                    .init(parameterID: .hapticSharpness, value: 0.1)
                ],
                relativeTime: 0,
                duration: 0.5
            )
            return ([ev], true)

        case .exitingTunnel:
            let events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.3),
                        .init(parameterID: .hapticSharpness, value: 0.1)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.7),
                        .init(parameterID: .hapticSharpness, value: 0.6)
                    ],
                    relativeTime: 0.3
                )
            ]
            return (events, false)

        case .arrivingStation:
            let events = (0..<3).map { i in
                let intensity: Float = [0.6, 0.3, 0.1][i]
                let sharpness: Float = [0.7, 0.5, 0.3][i]
                return CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: intensity),
                        .init(parameterID: .hapticSharpness, value: sharpness)
                    ],
                    relativeTime: TimeInterval(i) * 0.15
                )
            }
            return (events, false)

        case .doorsOpen:
            let events = (0..<2).map { i in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.5),
                        .init(parameterID: .hapticSharpness, value: 0.9)
                    ],
                    relativeTime: TimeInterval(i) * 0.2
                )
            }
            return (events, false)

        case .doorsClose:
            let events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.7),
                        .init(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.5),
                        .init(parameterID: .hapticSharpness, value: 0.9)
                    ],
                    relativeTime: 0.15
                )
            ]
            return (events, false)

        case .correctChar:
            let ev = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.2),
                    .init(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0
            )
            return ([ev], false)

        case .wrongChar:
            let ev = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.4),
                    .init(parameterID: .hapticSharpness, value: 0.1)
                ],
                relativeTime: 0
            )
            return ([ev], false)

        case .comboMilestone:
            let events = (0..<5).map { i in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.5 + Float(i) * 0.08),
                        .init(parameterID: .hapticSharpness, value: 0.7 + Float(i) * 0.05)
                    ],
                    relativeTime: TimeInterval(i) * 0.06
                )
            }
            return (events, false)

        case .perfectAccuracy:
            let events = (0..<4).map { i in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.3 + Float(i) * 0.15),
                        .init(parameterID: .hapticSharpness, value: 0.3 + Float(i) * 0.2)
                    ],
                    relativeTime: TimeInterval(i) * 0.08
                )
            }
            return (events, false)
        }
    }
}
