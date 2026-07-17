//
//  AppLogger.swift
//  TypeRailApp
//

import os

/// Thin wrapper over os.Logger for consistent log categories.
struct AppLogger {
    private let logger: Logger

    init<T>(for type: T.Type) {
        logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.dewaayam.TypeRailApp", category: String(describing: type))
    }

    func error(_ message: String) { logger.error("\(message)") }
    func warning(_ message: String) { logger.warning("\(message)") }
    func info(_ message: String) { logger.info("\(message)") }
}
