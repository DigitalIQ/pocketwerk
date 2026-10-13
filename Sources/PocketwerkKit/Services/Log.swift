import os

/// Unified log for the app module. Diagnostics export reads these entries back.
enum Log {
    nonisolated static let app = Logger(subsystem: "io.github.digitaliq.pocketwerk", category: "app")
}
