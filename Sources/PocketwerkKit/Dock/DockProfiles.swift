import AppKit
import Observation
import PocketwerkShared

/// What apply needs from the system besides the Dock. A protocol so tests can count quits and launches.
protocol ProfileSystem: AnyObject {
    /// Running apps with a Dock presence (activation policy regular).
    func runningApps() -> [(bundleID: String, path: String?)]
    func quit(bundleID: String)
    /// Starts an app in the background without stealing focus.
    func launch(appAt url: URL)
    /// Opens a file, folder or link without bringing its app to the front.
    func open(_ url: URL)
    func fileExists(_ path: String) -> Bool
    /// Current path of an app by bundle id.
    func locate(bundleID: String) -> String?
}

final class WorkspaceProfileSystem: ProfileSystem {
    func runningApps() -> [(bundleID: String, path: String?)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != getpid() }
            .compactMap { app in app.bundleIdentifier.map { ($0, app.bundleURL?.path) } }
    }

    func quit(bundleID: String) {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) { app.terminate() }
    }

    func launch(appAt url: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.addsToRecentItems = false
        NSWorkspace.shared.openApplication(at: url, configuration: config)
    }

    func open(_ url: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.open(url, configuration: config)
    }

    func fileExists(_ path: String) -> Bool { FileManager.default.fileExists(atPath: path) }

    func locate(bundleID: String) -> String? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path
    }
}

/// Outcome of applying a profile, shown in the UI and printed by the CLI.
nonisolated struct ProfileApplyResult: Hashable, Sendable {
    enum Status: String, Sendable { case applied, skippedActive, busy, notFound }
    var status: Status
    var profileName = ""
    /// Tiles left out because their file is gone.
    var missing: [String] = []
    var quit: [String] = []
    var launched: [String] = []
}

/// Saved copies of the whole macOS Dock: capture, edit, apply.
@Observable
final class DockProfiles {
    static let shared = DockProfiles()

    @ObservationIgnored let store: LibraryStore
    @ObservationIgnored var domain: DockDomain
    @ObservationIgnored var system: ProfileSystem
    private(set) var isApplying = false
    private(set) var lastResult: ProfileApplyResult?
    @ObservationIgnored private var lastApplyAt = Date.distantPast

    init(store: LibraryStore = .shared, domain: DockDomain = DockDomains.makeDefault(), system: ProfileSystem = WorkspaceProfileSystem()) {
        self.store = store
        self.domain = domain
        self.system = system
    }

    enum ProfileError: LocalizedError {
        case dockUnreadable, notFound, badFile
        var errorDescription: String? {
            switch self {
            case .dockUnreadable: String(localized: "The Dock is empty or could not be read.")
            case .notFound: String(localized: "Profile not found.")
            case .badFile: String(localized: "The file is not a Pocketwerk profile.")
            }
        }
    }

    // MARK: Startup

    /// Repairs profiles and applies the startup profile. Called once from `DockManager.start()`.
    func start() {
        repairProfiles()
        guard let id = store.settings.startupProfileID else { return }
        // Give the Dock and login items a moment; never during the first frame.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in apply(id, skipIfActive: true) }
    }

    /// Fills whichever half of a profile is missing: tiles from raw data, or raw data from tiles.
    func repairProfiles() {
        store.mutate(undoable: false) { lib in
            for i in lib.profiles.indices {
                let values = DockSnapshot.decode(lib.profiles[i].plistData)
                if lib.profiles[i].tiles.isEmpty, !DockSnapshot.isEmpty(values) {
                    lib.profiles[i].tiles = DockSnapshot.tiles(from: values)
                } else if !lib.profiles[i].tiles.isEmpty, DockSnapshot.isEmpty(values) {
                    lib.profiles[i].plistData = DockSnapshot.encode(DockSnapshot.rebuild(values, tiles: lib.profiles[i].tiles))
                }
            }
        }
    }

    // MARK: Reading the Dock

    func currentValues() -> DockSnapshot.Values {
        var values: DockSnapshot.Values = [:]
        for key in DockPlist.profileKeys {
            if let v = domain.value(forKey: key) { values[key] = v }
        }
        return values
    }

    /// Builds a profile from the current Dock without saving it.
    func makeProfileFromCurrentDock(name: String) throws -> DockProfile {
        let values = currentValues()
        guard !DockSnapshot.isEmpty(values) else { throw ProfileError.dockUnreadable }
        var p = DockProfile(name: name, plistData: DockSnapshot.encode(values))
        p.tiles = DockSnapshot.tiles(from: values)
        return p
    }

    /// Saves the current Dock as a new profile. nil when the Dock is empty or unreadable.
    @discardableResult
    func captureCurrent(name: String) -> DockProfile? {
        guard let p = try? makeProfileFromCurrentDock(name: name) else { return nil }
        store.mutate { $0.profiles.append(p) }
        return p
    }

    @discardableResult
    func createEmpty(name: String) -> DockProfile {
        let p = DockProfile(name: name, plistData: Data())
        store.mutate { $0.profiles.append(p) }
        return p
    }

    /// Overwrites a profile's tiles and Dock settings with the current Dock. Options stay.
    @discardableResult
    func saveCurrent(into id: UUID) -> Bool {
        let values = currentValues()
        guard !DockSnapshot.isEmpty(values), profile(id) != nil else { return false }
        updateProfile(id) { p in
            p.plistData = DockSnapshot.encode(values)
            p.tiles = DockSnapshot.tiles(from: values)
        }
        return true
    }

    /// "Save Current Dock to Active Profile".
    @discardableResult
    func saveCurrentToActive() -> Bool {
        guard let id = store.settings.lastAppliedProfileID else { return false }
        return saveCurrent(into: id)
    }

    // MARK: Apply

    func profile(_ id: UUID) -> DockProfile? { store.library.profiles.first { $0.id == id } }

    /// Finds a profile by UUID, exact name (case-insensitive) or a unique name prefix.
    func profile(matching query: String) -> DockProfile? {
        let all = store.library.profiles
        if let id = UUID(uuidString: query), let p = all.first(where: { $0.id == id }) { return p }
        if let p = all.first(where: { $0.name.caseInsensitiveCompare(query) == .orderedSame }) { return p }
        let prefixed = all.filter { $0.name.lowercased().hasPrefix(query.lowercased()) }
        return prefixed.count == 1 ? prefixed[0] : nil
    }

    /// True when the profile was the last one applied and the Dock still shows its tiles.
    func isActive(_ id: UUID) -> Bool {
        guard store.settings.lastAppliedProfileID == id, let p = profile(id) else { return false }
        let (values, _) = restorableValues(of: p)
        return DockSnapshot.signature(values) == DockSnapshot.signature(currentValues())
    }

    /// Rewrites the Dock with the profile and restarts it once. Then quits, launches and opens
    /// what the profile asks for. Overlapping calls are refused, so a profile is never half applied.
    @discardableResult
    func apply(_ profileID: UUID, skipIfActive: Bool? = nil) -> ProfileApplyResult {
        guard !isApplying else { return ProfileApplyResult(status: .busy) }
        guard let p = profile(profileID) else { return finish(ProfileApplyResult(status: .notFound)) }
        isApplying = true
        defer { isApplying = false }

        var result = ProfileApplyResult(status: .applied, profileName: p.name)
        if skipIfActive ?? store.settings.skipIfActive, isActive(profileID) {
            result.status = .skippedActive
            return finish(result)
        }

        // Keep the Dock the user built since the last switch. Not while the Dock may still be
        // restarting from the previous apply: it may not have written its state yet.
        if store.settings.autoSaveOnSwitch, let last = store.settings.lastAppliedProfileID, last != profileID,
           Date().timeIntervalSince(lastApplyAt) > 3 {
            saveCurrent(into: last)
        }

        let (values, missing) = restorableValues(of: p)
        result.missing = missing
        for key in DockPlist.profileKeys {
            if let v = values[key] {
                domain.set(v, forKey: key)
            } else if key == DockPlist.appsKey || key == DockPlist.othersKey {
                domain.set([DockPlist.Entry](), forKey: key)
            }
        }
        domain.commit(restartDock: true)
        lastApplyAt = Date()
        store.mutate(undoable: false) { $0.settings.lastAppliedProfileID = profileID }

        let targets = DockSnapshot.appTargets(values)
        if p.quitOthers, !p.keepAppsOpen {
            let keep = Set(targets.compactMap(\.bundleID) + p.keepRunning
                           + [PWShared.mainBundleID, "com.apple.finder", "com.apple.dock"])
            let keepPaths = Set(targets.map(\.path))
            for app in system.runningApps() where !keep.contains(app.bundleID)
                && !app.bundleID.hasPrefix(PWShared.launcherBundleIDPrefix)
                && !app.bundleID.hasPrefix(PWShared.spacerBundleIDPrefix)
                && !(app.path.map(keepPaths.contains) ?? false) {
                system.quit(bundleID: app.bundleID)
                result.quit.append(app.bundleID)
            }
        }
        if p.launchApps {
            // Running apps are left alone, so their windows (and minimized ones) stay as they are.
            let running = system.runningApps()
            let runningIDs = Set(running.map(\.bundleID))
            let runningPaths = Set(running.compactMap(\.path))
            for t in targets where !(t.bundleID.map(runningIDs.contains) ?? false) && !runningPaths.contains(t.path)
                && !(t.bundleID?.hasPrefix(PWShared.spacerBundleIDPrefix) ?? false) {
                system.launch(appAt: URL(fileURLWithPath: t.path))
                result.launched.append(t.bundleID ?? t.path)
            }
        }
        for url in p.openAfterApply {
            if url.isFileURL, !system.fileExists(url.path) {
                result.missing.append(url.lastPathComponent)
                continue
            }
            system.open(url)
        }
        return finish(result)
    }

    private func finish(_ r: ProfileApplyResult) -> ProfileApplyResult {
        lastResult = r
        return r
    }

    /// The profile's Dock values with missing files dropped (or moved apps found again).
    func restorableValues(of p: DockProfile) -> (DockSnapshot.Values, [String]) {
        var values = DockSnapshot.decode(p.plistData)
        if DockSnapshot.isEmpty(values), !p.tiles.isEmpty {
            values = DockSnapshot.rebuild(values, tiles: p.tiles)
        }
        let sys = system
        let cleaned = DockSnapshot.removingMissing(values, exists: { sys.fileExists($0) }, locate: { sys.locate(bundleID: $0) })
        return (cleaned.values, cleaned.missing)
    }

    // MARK: Editing

    func updateProfile(_ id: UUID, undoable: Bool = true, _ change: (inout DockProfile) -> Void) {
        store.mutate(undoable: undoable) { lib in
            guard let i = lib.profiles.firstIndex(where: { $0.id == id }) else { return }
            change(&lib.profiles[i])
        }
    }

    /// Replaces the editor tiles and writes them into the raw Dock data, so apply uses them.
    func setTiles(_ tiles: [DockTile], of id: UUID) {
        updateProfile(id) { p in
            p.tiles = tiles
            p.plistData = DockSnapshot.encode(DockSnapshot.rebuild(DockSnapshot.decode(p.plistData), tiles: tiles))
        }
    }

    @discardableResult
    func duplicate(_ id: UUID) -> DockProfile? {
        guard var copy = profile(id) else { return nil }
        copy.id = UUID()
        copy.name = String(localized: "\(copy.name) Copy")
        copy.createdAt = Date()
        copy.hotkey = nil
        let c = copy
        store.mutate { lib in
            let at = (lib.profiles.firstIndex { $0.id == id } ?? lib.profiles.count - 1) + 1
            lib.profiles.insert(c, at: at)
        }
        return copy
    }

    func delete(_ id: UUID) {
        store.mutate { lib in
            lib.profiles.removeAll { $0.id == id }
            if lib.settings.startupProfileID == id { lib.settings.startupProfileID = nil }
            if lib.settings.lastAppliedProfileID == id { lib.settings.lastAppliedProfileID = nil }
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        store.mutate { $0.profiles.move(fromOffsets: source, toOffset: destination) }
    }

    // MARK: Export and import

    func export(_ id: UUID, to url: URL) throws {
        guard let p = profile(id) else { throw ProfileError.notFound }
        try LibraryStore.encoder.encode(p).write(to: url, options: .atomic)
    }

    /// Adds the profile from a JSON file. Never replaces an existing one: a clashing id gets a new one.
    @discardableResult
    func importProfile(from url: URL) throws -> DockProfile {
        let data = try Data(contentsOf: url)
        guard var p = try? LibraryStore.decoder.decode(DockProfile.self, from: data) else { throw ProfileError.badFile }
        if profile(p.id) != nil { p.id = UUID() }
        if store.library.profiles.contains(where: { $0.name == p.name }) {
            p.name = String(localized: "\(p.name) (Imported)")
        }
        if p.tiles.isEmpty { p.tiles = DockSnapshot.tiles(from: DockSnapshot.decode(p.plistData)) }
        let imported = p
        store.mutate { $0.profiles.append(imported) }
        return imported
    }
}
