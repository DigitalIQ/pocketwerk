import AppKit
import PocketwerkShared

// OWNER: dock agent. Placeholder with the final API.

/// Creates one launcher app bundle per DockSlot, keeps its icon in sync,
/// adds/removes it from the macOS Dock, and listens for launcher clicks.
final class DockManager {
    static let shared = DockManager()

    /// Folder for generated launchers: ~/Applications/Pocketwerk, or $POCKETWERK_LAUNCHER_DIR for development runs.
    var launcherFolder: URL {
        if let env = ProcessInfo.processInfo.environment["POCKETWERK_LAUNCHER_DIR"] {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Pocketwerk", isDirectory: true)
    }

    /// Start listening for launcher clicks and library changes.
    func start() {
        DistributedNotificationCenter.default().addObserver(forName: PWShared.openSlotNotification, object: nil, queue: .main) { note in
            guard let id = (note.object as? String).flatMap(UUID.init) else { return }
            MainActor.assumeIsolated { PopupController.shared.toggle(slotID: id) }
        }
    }

    /// Creates or updates the launcher bundle for a slot. Returns its path.
    @discardableResult
    func installLauncher(for slotID: UUID) throws -> URL {
        throw CocoaError(.featureUnsupported)
    }

    func removeLauncher(for slotID: UUID) {}

    /// Adds the slot's launcher to the macOS Dock (restarts the Dock).
    func addToDock(slotID: UUID) {}

    func removeFromDock(slotID: UUID) {}

    func isInDock(slotID: UUID) -> Bool { false }

    /// Re-renders all launcher icons (debounced by caller).
    func refreshIcons() {}
}
