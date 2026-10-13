import AppKit

/// What an import would change. Shown before the user picks Merge or Replace.
nonisolated struct ImportSummary: Equatable, Sendable {
    /// Groups Merge would add.
    var newGroups: [String] = []
    /// Groups Merge skips because a group with the same ID or name exists.
    var existingGroups: [String] = []
    var newProfiles: [String] = []
    var existingProfiles: [String] = []
    var newThemes = 0
    /// Apps in the file that are not installed on this Mac ("Group: App").
    var missingApps: [String] = []
    /// Groups and items in the file in total.
    var totalGroups = 0
    var totalItems = 0
}

/// Pure import logic: Merge adds only what is new and never deletes; Replace swaps the library
/// but keeps settings that only make sense on this Mac.
nonisolated enum LibraryMerge {
    static func summary(current: Library, imported: Library, isInstalled: (DockItem) -> Bool) -> ImportSummary {
        var s = ImportSummary()
        s.totalGroups = imported.groups.count
        s.totalItems = imported.groups.reduce(0) { $0 + $1.items.count }
        for g in imported.groups {
            if groupExists(g, in: current) { s.existingGroups.append(g.name) } else { s.newGroups.append(g.name) }
            for item in g.items where item.kind == .app && !isInstalled(item) {
                s.missingApps.append("\(g.name): \(item.displayName)")
            }
        }
        for p in imported.profiles {
            if profileExists(p, in: current) { s.existingProfiles.append(p.name) } else { s.newProfiles.append(p.name) }
        }
        let themeIDs = Set(current.customThemes.map(\.id))
        s.newThemes = imported.customThemes.filter { !themeIDs.contains($0.id) }.count
        return s
    }

    static func groupExists(_ g: ItemGroup, in lib: Library) -> Bool {
        lib.groups.contains { $0.id == g.id || $0.name.caseInsensitiveCompare(g.name) == .orderedSame }
    }

    static func profileExists(_ p: DockProfile, in lib: Library) -> Bool {
        lib.profiles.contains { $0.id == p.id || $0.name.caseInsensitiveCompare(p.name) == .orderedSame }
    }

    /// Adds new groups, their slots, new profiles, themes and spacers. Never removes or changes existing data.
    /// Returns the merged library and the slots whose launchers should be rebuilt.
    static func merge(current: Library, imported: Library) -> (library: Library, rebuild: [UUID]) {
        var lib = current
        let added = imported.groups.filter { !groupExists($0, in: current) }
        lib.groups += added
        let addedIDs = Set(added.map(\.id))

        var rebuild: [UUID] = []
        let slotIDs = Set(current.slots.map(\.id))
        for var slot in imported.slots where !slotIDs.contains(slot.id) {
            slot.groupIDs = slot.groupIDs.filter { addedIDs.contains($0) }
            guard !slot.groupIDs.isEmpty else { continue }
            if slot.launcherPath != nil || slot.pinnedInDock { rebuild.append(slot.id) }
            slot.launcherPath = nil
            slot.iconHash = nil
            slot.pinnedInDock = false
            lib.slots.append(slot)
        }
        lib.profiles += imported.profiles.filter { !profileExists($0, in: current) }
        let themeIDs = Set(current.customThemes.map(\.id))
        lib.customThemes += imported.customThemes.filter { !themeIDs.contains($0.id) }
        let spacerIDs = Set(current.spacers.map(\.id))
        lib.spacers += imported.spacers.filter { !spacerIDs.contains($0.id) }.map { var s = $0; s.launcherPath = nil; return s }
        for (k, v) in imported.usage.launches { lib.usage.launches[k] = max(v, lib.usage.launches[k] ?? 0) }
        for (k, v) in imported.usage.lastLaunch { lib.usage.lastLaunch[k] = max(v, lib.usage.lastLaunch[k] ?? .distantPast) }
        return (lib, rebuild)
    }

    /// Takes the imported library as it is, except settings tied to this Mac.
    static func replace(current: Library, imported: Library) -> (library: Library, rebuild: [UUID]) {
        var lib = imported
        lib.settings.launchAtLogin = current.settings.launchAtLogin
        lib.settings.syncFolderPath = current.settings.syncFolderPath
        lib.settings.lockDockDisplayID = current.settings.lockDockDisplayID
        lib.settings.onboardingDone = true
        lib.settings.lastUpdateCheck = current.settings.lastUpdateCheck
        lib.settings.skippedVersion = current.settings.skippedVersion
        let rebuild = lib.slots.filter { $0.launcherPath != nil || $0.pinnedInDock }.map(\.id)
        for i in lib.slots.indices {
            lib.slots[i].launcherPath = nil
            lib.slots[i].iconHash = nil
            lib.slots[i].pinnedInDock = false
        }
        for i in lib.spacers.indices { lib.spacers[i].launcherPath = nil }
        return (lib, rebuild)
    }
}

/// Export, import and the data folder, with panels. Used by Settings > Backup.
enum BackupService {
    enum Mode { case merge, replace }

    static func exportWithPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        let date = Date().formatted(.iso8601.year().month().day())
        panel.nameFieldStringValue = "Pocketwerk Backup \(date).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try LibraryStore.shared.export(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    /// Reads a backup file. Returns nil and shows an alert when it cannot be read.
    static func pickImportFile() -> Library? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let data = try? Data(contentsOf: url), let lib = LibraryStore.decodeLeniently(data) else {
            let alert = NSAlert()
            alert.messageText = String(localized: "This file is not a Pocketwerk backup.")
            alert.runModal()
            return nil
        }
        return lib
    }

    static func summary(for imported: Library) -> ImportSummary {
        LibraryMerge.summary(current: LibraryStore.shared.library, imported: imported) { item in
            if let bid = item.bundleID, AppLocator.url(forBundleID: bid) != nil { return true }
            return FileManager.default.fileExists(atPath: item.url.path)
        }
    }

    /// Applies the import (undoable), removes launchers of slots that are gone, and rebuilds launchers.
    static func apply(_ imported: Library, mode: Mode) {
        let store = LibraryStore.shared
        let before = store.library
        let result = mode == .merge
            ? LibraryMerge.merge(current: before, imported: imported)
            : LibraryMerge.replace(current: before, imported: imported)
        if mode == .replace {
            let kept = Set(result.library.slots.map(\.id))
            for slot in before.slots where !kept.contains(slot.id) && slot.launcherPath != nil {
                DockManager.shared.removeLauncher(for: slot.id)
            }
        }
        store.replace(with: result.library)
        store.removeSmartOnlySlots()
        for id in result.rebuild where store.slot(id) != nil { _ = try? DockManager.shared.installLauncher(for: id) }
        Log.app.info("Imported backup (\(mode == .merge ? "merge" : "replace")), \(result.rebuild.count) launchers to rebuild")
        DockManager.shared.refreshIcons()
    }

    static func showDataFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([LibraryStore.shared.fileURL])
    }

    /// Lets the user pick a folder for an extra copy of the library (for example in iCloud Drive).
    static func chooseSyncFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Use Folder")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        LibraryStore.shared.settings.syncFolderPath = url.path
        LibraryStore.shared.saveNow()
    }
}
