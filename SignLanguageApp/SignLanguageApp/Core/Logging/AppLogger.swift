import os
import Foundation

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.signlanguageapp"

    static let `default` = Logger(
        subsystem: subsystem,
        category: "general"
    )
}
