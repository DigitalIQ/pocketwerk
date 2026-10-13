import AppKit

// OWNER: dock agent. Placeholder with the final API.

/// profile app-style presets: snapshot and restore the whole macOS Dock.
final class DockProfiles {
    static let shared = DockProfiles()

    /// Saves the current Dock as a new profile.
    @discardableResult
    func captureCurrent(name: String) -> DockProfile? { nil }

    /// Rewrites the Dock with the profile and restarts it.
    func apply(_ profileID: UUID) {}
}
