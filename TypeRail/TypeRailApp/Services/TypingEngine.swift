//
//  TypingEngine.swift
//  TypeRailApp
//

import Foundation
import Observation

/// Typing metrics computed per-station.
struct TypingResult: Sendable {
    let correctChars: Int
    let totalChars: Int
    let errors: Int
    let elapsedSeconds: TimeInterval

    var accuracy: Double {
        guard totalChars > 0 else { return 0 }
        return Double(correctChars) / Double(totalChars) * 100
    }

    /// Words Per Minute (1 word = 5 keystrokes).
    var wpm: Double {
        guard elapsedSeconds > 0 else { return 0 }
        return (Double(correctChars) / 5.0) / (elapsedSeconds / 60.0)
    }
}

/// Typing validation + scoring logic. Stateless — receives input, returns result.
enum TypingEngine {
    /// Validates typed text against target station name character by character.
    static func validate(typed: String, target: String) -> TypingResult {
        let targetChars = Array(target)
        let typedChars = Array(typed)
        var correct = 0
        var errors = 0

        for (index, char) in typedChars.enumerated() {
            if index < targetChars.count, char == targetChars[index] {
                correct += 1
            } else {
                errors += 1
            }
        }

        return TypingResult(
            correctChars: correct,
            totalChars: targetChars.count,
            errors: errors,
            elapsedSeconds: 0 // caller sets this
        )
    }

    /// Score for completing a station typing challenge.
    static func score(for result: TypingResult, comboMultiplier: Double, timeBonus: Bool) -> Int {
        guard result.totalChars > 0 else { return 0 }

        let base: Int
        if result.errors == 0 {
            base = 100
        } else if result.errors <= 2 {
            base = 50
        } else {
            base = 10
        }

        let multiplier = min(comboMultiplier, 5.0)
        let bonus = timeBonus ? 50 : 0
        return Int(Double(base) * multiplier) + bonus
    }

    /// Next combo multiplier given current errors state.
    static func nextCombo(currentErrors: Int, previousMultiplier: Double) -> Double {
        if currentErrors > 0 { return 1.0 }
        let next = previousMultiplier + 0.5
        return min(next, 5.0)
    }
}
