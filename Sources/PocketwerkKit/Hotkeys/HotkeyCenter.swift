import AppKit

// OWNER: app agent. Placeholder with the final API.

/// Global hotkeys via Carbon RegisterEventHotKey (no Accessibility permission needed).
/// Registers: settings.mainHotkey (all groups), each group's hotkey, each slot's hotkey, each profile's hotkey.
final class HotkeyCenter {
    static let shared = HotkeyCenter()

    /// Registers all hotkeys and re-syncs on every `.libraryDidChange`.
    func start() {}

    /// Human readable form, e.g. "⌃⌥P".
    static func describe(_ hotkey: Hotkey) -> String { "" }
}
