//
//  AppLogger.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import Foundation
import OSLog

/// Centralised `os.Logger` provider. Use `AppLogger.default` instead of `print`.
enum AppLogger {
    private static let subsystem =
        Bundle.main.bundleIdentifier ?? "com.signlanguageapp"

    static let `default` = Logger(
        subsystem: subsystem,
        category: "general"
    )
}
