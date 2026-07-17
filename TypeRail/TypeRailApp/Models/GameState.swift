//
//  GameState.swift
//  TypeRailApp
//

/// Phase of the game for state-driven UI transitions.
enum GamePhase: Sendable {
    case idle          /// Waiting to start
    case traveling     /// Train moving between stations, typing active
    case slowed        /// Speed penalty from typing error
    case docked        /// Train arrived at station, showing arrival screen
    case exploring     /// Look Around viewer open
    case finished      /// Trip completed, show summary
}
