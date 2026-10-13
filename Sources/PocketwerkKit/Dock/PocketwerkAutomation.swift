import AppKit

/// The small public surface the App Intents in the `Pocketwerk` executable call.
/// Everything else in PocketwerkKit stays internal.
public enum PocketwerkAutomation {
    public struct Entry: Hashable, Sendable {
        public let id: UUID
        public let name: String
    }

    public static func groups() -> [Entry] {
        LibraryStore.shared.library.orderedGroups.map { Entry(id: $0.id, name: $0.name) }
    }

    public static func profiles() -> [Entry] {
        LibraryStore.shared.library.profiles.map { Entry(id: $0.id, name: $0.name) }
    }

    /// Shows the group's popup at the pointer.
    public static func showGroup(_ id: UUID) -> Bool {
        guard LibraryStore.shared.group(id) != nil else { return false }
        PopupController.shared.show(groupIDs: [id], slotID: nil, anchor: nil, source: .hotkey)
        return true
    }

    public static func openAll(_ id: UUID) -> Bool {
        guard let g = LibraryStore.shared.group(id) else { return false }
        ItemOpener.openAll(g)
        return true
    }

    public static func hideAll(_ id: UUID) -> Bool {
        guard let g = LibraryStore.shared.group(id) else { return false }
        ItemOpener.hideAll(LibraryStore.shared.visibleItems(of: g))
        return true
    }

    public static func quitAll(_ id: UUID) -> Bool {
        guard let g = LibraryStore.shared.group(id) else { return false }
        ItemOpener.quitAll(LibraryStore.shared.visibleItems(of: g), force: false)
        return true
    }

    /// Applies a Dock profile. Returns a short status line for Shortcuts.
    public static func applyProfile(_ id: UUID, interactive: Bool = true) -> String {
        let r = DockProfiles.shared.apply(id, skipIfActive: nil, interactive: interactive)
        return describe(r)
    }

    public static func applyNextProfile() -> String {
        describe(DockProfiles.shared.applyNext())
    }

    private static func describe(_ r: ProfileApplyResult) -> String {
        switch r.status {
        case .applied:
            r.missing.isEmpty ? String(localized: "Applied \(r.profileName).")
                : String(localized: "Applied \(r.profileName). Missing: \(r.missing.joined(separator: ", ")).")
        case .skippedActive: String(localized: "\(r.profileName) is already active.")
        case .busy: String(localized: "Another profile is being applied.")
        case .notFound: String(localized: "Profile not found.")
        }
    }
}
