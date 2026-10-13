import AppKit
import Observation
import PocketwerkShared

/// A launcher-backed Dock tile: a slot (opens a popup) or a custom spacer (shows text or an image).
nonisolated enum LauncherTarget: Hashable, Sendable {
    case slot(UUID)
    case spacer(UUID)

    var id: UUID {
        switch self { case .slot(let id), .spacer(let id): id }
    }

    var kind: LauncherSpec.Kind {
        switch self { case .slot: .slot; case .spacer: .spacer }
    }

    var bundleID: String {
        switch self {
        case .slot(let id): PWShared.launcherBundleIDPrefix + id.uuidString
        case .spacer(let id): PWShared.spacerBundleIDPrefix + id.uuidString
        }
    }
}

/// A failed launcher build, with details for "Copy Details".
nonisolated struct LauncherFailure: Hashable, Sendable {
    var message: String
    var details: String
}

/// Creates one launcher app bundle per DockSlot (and per custom spacer), keeps its icon in sync,
/// adds/removes it from the macOS Dock, and listens for launcher clicks.
@Observable
final class DockManager {
    static let shared = DockManager()

    @ObservationIgnored let store: LibraryStore
    @ObservationIgnored var domain: DockDomain
    @ObservationIgnored private let folderOverride: URL?
    /// Last launcher error, shown with a "Copy Details" button.
    var lastFailure: LauncherFailure?
    /// Launchers being built right now.
    private(set) var busy: Set<UUID> = []

    @ObservationIgnored private var knownSlots: [UUID: DockSlot] = [:]
    @ObservationIgnored private var knownSpacers: [UUID: CustomSpacer] = [:]
    /// Spacers have no stored icon hash; this one lives for the session.
    @ObservationIgnored private var spacerIconHashes: [UUID: String] = [:]
    @ObservationIgnored private var iconWork: DispatchWorkItem?
    @ObservationIgnored private var restartPending = false
    @ObservationIgnored private var started = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var relay: DistributedRelay?
    @ObservationIgnored private lazy var template: LauncherTemplate? = LauncherTemplate.locate()

    init(store: LibraryStore = .shared, domain: DockDomain = DockDomains.makeDefault(), folder: URL? = nil) {
        self.store = store
        self.domain = domain
        self.folderOverride = folder
    }

    /// Folder for generated launchers: ~/Applications/Pocketwerk, or $POCKETWERK_LAUNCHER_DIR for development runs.
    var launcherFolder: URL {
        if let folderOverride { return folderOverride }
        if let env = ProcessInfo.processInfo.environment["POCKETWERK_LAUNCHER_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Pocketwerk", isDirectory: true)
    }

    var spacerFolder: URL { launcherFolder.appendingPathComponent("Spacers", isDirectory: true) }

    // MARK: Start

    /// Start listening for launcher clicks and library changes.
    func start() {
        guard !started else { return }
        started = true
        // The main app is almost always inactive when a tile is clicked; deliver anyway.
        relay = DistributedRelay(name: PWShared.openSlotNotification) { [weak self] note in
            MainActor.assumeIsolated { self?.handleOpenRequest(note) }
        }
        observers.append(NotificationCenter.default.addObserver(forName: .libraryDidChange, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncWithLibrary() }
        })
        rememberLibrary()
        DockProfiles.shared.start()
        // Rebuild launchers made by an older app version and heal icons, after launch settles.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.maintainLaunchers() }
    }

    private func handleOpenRequest(_ note: Notification) {
        guard let id = (note.object as? String).flatMap(UUID.init) else { return }
        let info = note.userInfo ?? [:]
        // A click older than 2 s was queued while the app was busy; opening it now would surprise.
        if let t = info[PWShared.timeKey] as? Double, Date().timeIntervalSince1970 - t > 2 { return }
        var anchor: CGPoint?
        if let x = info[PWShared.xKey] as? Double, let y = info[PWShared.yKey] as? Double { anchor = CGPoint(x: x, y: y) }
        openSlot(id, anchor: anchor)
    }

    /// Opens the popup of a slot above its tile.
    func openSlot(_ id: UUID, anchor: CGPoint?) {
        guard store.slot(id) != nil else { return }
        PopupController.shared.toggle(groupIDs: store.groups(for: id).map(\.id), slotID: id, anchor: anchor)
    }

    private func rememberLibrary() {
        knownSlots = Dictionary(store.library.slots.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        knownSpacers = Dictionary(store.library.spacers.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Keeps launchers in step with the library: deleted slots lose their launcher, renamed ones
    /// move in place, and icons are re-rendered (debounced) when their inputs change.
    private func syncWithLibrary() {
        let lib = store.library
        let slotIDs = Set(lib.slots.map(\.id))
        for (id, old) in knownSlots where !slotIDs.contains(id) && old.launcherPath != nil {
            deleteBundle(.slot(id), path: old.launcherPath)
        }
        let spacerIDs = Set(lib.spacers.map(\.id))
        for (id, old) in knownSpacers where !spacerIDs.contains(id) && old.launcherPath != nil {
            deleteBundle(.spacer(id), path: old.launcherPath)
        }
        for slot in lib.slots {
            guard let path = slot.launcherPath else { continue }
            if knownSlots[slot.id]?.name != slot.name || !FileManager.default.fileExists(atPath: path) {
                installInBackground(.slot(slot.id))
            }
        }
        for spacer in lib.spacers {
            guard let path = spacer.launcherPath else { continue }
            let old = knownSpacers[spacer.id]
            if old?.text != spacer.text || !FileManager.default.fileExists(atPath: path) {
                installInBackground(.spacer(spacer.id))
            }
        }
        rememberLibrary()
        scheduleIconRefresh()
    }

    /// Rebuilds stale or missing launchers. Called once after start.
    func maintainLaunchers() {
        guard let template else { return }
        for slot in store.library.slots where slot.launcherPath != nil {
            let path = URL(fileURLWithPath: slot.launcherPath!)
            if !LauncherBuilder.isCurrent(path, spec: spec(for: .slot(slot.id), buildID: template.buildID)) {
                installInBackground(.slot(slot.id))
            }
        }
        for spacer in store.library.spacers where spacer.launcherPath != nil {
            let path = URL(fileURLWithPath: spacer.launcherPath!)
            if !LauncherBuilder.isCurrent(path, spec: spec(for: .spacer(spacer.id), buildID: template.buildID)) {
                installInBackground(.spacer(spacer.id))
            }
        }
        refreshIcons()
    }

    // MARK: Install

    /// Creates or updates the launcher bundle for a slot. Returns its path.
    @discardableResult
    func installLauncher(for slotID: UUID) throws -> URL {
        try install(.slot(slotID))
    }

    @discardableResult
    func installSpacer(_ spacerID: UUID) throws -> URL {
        try install(.spacer(spacerID))
    }

    /// Synchronous install, for buttons and the CLI.
    @discardableResult
    func install(_ target: LauncherTarget) throws -> URL {
        let job = try prepare(target)
        do {
            if job.needsBuild {
                try LauncherBuilder.build(spec: job.spec, template: job.template, iconPNG: job.icns, destination: job.destination)
            }
        } catch {
            fail(target, error)
            throw error
        }
        finish(job)
        return job.destination
    }

    /// Same as `install`, with the file work (copy, sign) off the main thread.
    func installInBackground(_ target: LauncherTarget) {
        guard !busy.contains(target.id) else { return }
        let job: InstallJob
        do { job = try prepare(target) } catch { fail(target, error); return }
        guard job.needsBuild else { finish(job); return }
        busy.insert(target.id)
        Task {
            do {
                try await Task.detached(priority: .utility) {
                    try LauncherBuilder.build(spec: job.spec, template: job.template, iconPNG: job.icns, destination: job.destination)
                }.value
                finish(job)
            } catch {
                fail(target, error)
            }
            busy.remove(target.id)
        }
    }

    private struct InstallJob: Sendable {
        var target: LauncherTarget
        var spec: LauncherSpec
        var template: LauncherTemplate
        var destination: URL
        var needsBuild: Bool
        var icns: Data?
        var hash: String
        var wasRunning: Bool
    }

    /// Main-actor part before the build: names, rename move, icon art, stopping a running launcher.
    private func prepare(_ target: LauncherTarget) throws -> InstallJob {
        guard let template else { throw LauncherError.noTemplate }
        guard let name = displayName(target) else { throw DockProfiles.ProfileError.notFound }
        let spec = spec(for: target, buildID: template.buildID)
        let destination = destinationURL(for: target, name: name)
        var wasRunning = false
        // Renamed: move the old bundle so the Dock pin can follow it.
        if let old = launcherPath(target), old != destination.path, FileManager.default.fileExists(atPath: old) {
            wasRunning = stopLauncher(target)
            try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: URL(fileURLWithPath: old), to: destination)
            LauncherBuilder.unregister(URL(fileURLWithPath: old))
        }
        let needsBuild = !LauncherBuilder.isCurrent(destination, spec: spec)
        if needsBuild { wasRunning = stopLauncher(target) || wasRunning }
        let (art, hash) = iconArt(target)
        let icns = LauncherIcon.png(LauncherIcon.compose(art.image, clip: art.clip), pixels: 1024)
        return InstallJob(target: target, spec: spec, template: template, destination: destination,
                          needsBuild: needsBuild, icns: icns, hash: hash, wasRunning: wasRunning)
    }

    /// Main-actor part after the build: custom icon (after signing), registration, Dock path, relaunch.
    private func finish(_ job: InstallJob) {
        let (art, hash) = iconArt(job.target)
        applyIcon(art, to: job.destination, id: job.target.id)
        LauncherBuilder.register(job.destination)
        let path = job.destination.path
        switch job.target {
        case .slot(let id):
            store.updateSlot(id, undoable: false) { s in
                s.launcherPath = path
                s.iconHash = hash
                s.launcherBuild = PWShared.launcherFormat
            }
        case .spacer(let id):
            spacerIconHashes[id] = hash
            store.mutate(undoable: false) { lib in
                guard let i = lib.spacers.firstIndex(where: { $0.id == id }) else { return }
                lib.spacers[i].launcherPath = path
            }
        }
        if isInDock(job.target) {
            let label = displayName(job.target) ?? ""
            modifyDock { DockPlist.adding(app: path, label: label, bundleID: job.target.bundleID, to: $0) }
        }
        if job.wasRunning { launchQuietly(job.destination) }
        rememberLibrary()
        if lastFailure != nil, busy.subtracting([job.target.id]).isEmpty { lastFailure = nil }
    }

    private func fail(_ target: LauncherTarget, _ error: Error) {
        let name = displayName(target) ?? target.id.uuidString
        lastFailure = LauncherFailure(
            message: String(localized: "The Dock tile for \"\(name)\" could not be built."),
            details: "\(name) [\(target.bundleID)]\n\(error.localizedDescription)\n\(error)")
        NSLog("Pocketwerk: launcher build failed: \(error)")
    }

    func spec(for target: LauncherTarget, buildID: String) -> LauncherSpec {
        let mainPath = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.bundlePath : ""
        let dataDir = ProcessInfo.processInfo.environment["POCKETWERK_DATA_DIR"].flatMap { $0.isEmpty ? nil : $0 }
        return LauncherSpec(id: target.id, kind: target.kind, name: displayName(target) ?? "",
                            mainAppPath: mainPath, buildID: buildID, dataDir: dataDir)
    }

    private func displayName(_ target: LauncherTarget) -> String? {
        switch target {
        case .slot(let id): store.slot(id)?.name
        case .spacer(let id): store.library.spacers.first { $0.id == id }.map { $0.text.isEmpty ? " " : $0.text }
        }
    }

    func launcherPath(_ target: LauncherTarget) -> String? {
        switch target {
        case .slot(let id): store.slot(id)?.launcherPath
        case .spacer(let id): store.library.spacers.first { $0.id == id }?.launcherPath
        }
    }

    /// `<folder>/<name>.app`; a bundle of another slot with the same name gets a number.
    private func destinationURL(for target: LauncherTarget, name: String) -> URL {
        let folder = target.kind == .spacer ? spacerFolder : launcherFolder
        let base = LauncherBuilder.bundleName(for: target.kind == .spacer ? "Spacer \(name)" : name)
        for n in 1...99 {
            let file = n == 1 ? base : "\(base) \(n)"
            let url = folder.appendingPathComponent("\(file).app", isDirectory: true)
            guard let info = LauncherBuilder.readInfo(url) else { return url }
            if info["CFBundleIdentifier"] as? String == target.bundleID { return url }
        }
        return folder.appendingPathComponent("\(base) \(target.id.uuidString.prefix(8)).app", isDirectory: true)
    }

    // MARK: Running launchers

    /// Asks a running launcher to quit and waits up to 1.5 s. Returns true if it was running.
    @discardableResult
    private func stopLauncher(_ target: LauncherTarget) -> Bool {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID)
        guard !apps.isEmpty else { return false }
        DistributedNotificationCenter.default().postNotificationName(
            PWShared.launcherQuitNotification, object: target.id.uuidString, userInfo: nil, deliverImmediately: true)
        apps.forEach { $0.terminate() }
        let deadline = Date().addingTimeInterval(1.5)
        while apps.contains(where: { !$0.isTerminated }), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        apps.filter { !$0.isTerminated }.forEach { $0.forceTerminate() }
        return true
    }

    private func launchQuietly(_ url: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.addsToRecentItems = false
        config.arguments = [PWShared.quietLaunchArgument]
        NSWorkspace.shared.openApplication(at: url, configuration: config)
    }

    // MARK: Remove

    func removeLauncher(for slotID: UUID) {
        deleteBundle(.slot(slotID), path: store.slot(slotID)?.launcherPath ?? knownSlots[slotID]?.launcherPath)
        store.updateSlot(slotID, undoable: false) { s in
            s.launcherPath = nil
            s.iconHash = nil
            s.pinnedInDock = false
        }
    }

    func removeSpacer(_ spacerID: UUID) {
        deleteBundle(.spacer(spacerID), path: launcherPath(.spacer(spacerID)) ?? knownSpacers[spacerID]?.launcherPath)
        store.mutate(undoable: false) { lib in
            guard let i = lib.spacers.firstIndex(where: { $0.id == spacerID }) else { return }
            lib.spacers[i].launcherPath = nil
        }
    }

    /// Quits the launcher, takes it out of the Dock and deletes the bundle and its icon.
    private func deleteBundle(_ target: LauncherTarget, path: String?) {
        stopLauncher(target)
        if dockContains(path: path, bundleID: target.bundleID) {
            modifyDock { DockPlist.removing(path: path, bundleID: target.bundleID, from: $0) }
        }
        if let path {
            let url = URL(fileURLWithPath: path)
            // Only ever delete our own bundles.
            if LauncherBuilder.readInfo(url)?["CFBundleIdentifier"] as? String == target.bundleID {
                LauncherBuilder.unregister(url)
                try? FileManager.default.removeItem(at: url)
            }
        }
        try? FileManager.default.removeItem(at: PWShared.iconURL(id: target.id.uuidString))
    }

    // MARK: Dock

    /// Adds the slot's launcher to the macOS Dock (restarts the Dock).
    func addToDock(slotID: UUID) { addToDock(.slot(slotID)) }

    func removeFromDock(slotID: UUID) { removeFromDock(.slot(slotID)) }

    func isInDock(slotID: UUID) -> Bool { isInDock(.slot(slotID)) }

    func addToDock(_ target: LauncherTarget) {
        var path = launcherPath(target)
        if path == nil || !FileManager.default.fileExists(atPath: path!) {
            do { path = try install(target).path } catch { return }
        }
        guard let path, let label = displayName(target) else { return }
        modifyDock { DockPlist.adding(app: path, label: label, bundleID: target.bundleID, to: $0) }
        if case .slot(let id) = target { store.updateSlot(id, undoable: false) { $0.pinnedInDock = true } }
    }

    func removeFromDock(_ target: LauncherTarget) {
        let path = launcherPath(target)
        modifyDock { DockPlist.removing(path: path, bundleID: target.bundleID, from: $0) }
        if case .slot(let id) = target { store.updateSlot(id, undoable: false) { $0.pinnedInDock = false } }
    }

    func isInDock(_ target: LauncherTarget) -> Bool {
        dockContains(path: launcherPath(target), bundleID: target.bundleID)
    }

    private func dockContains(path: String?, bundleID: String) -> Bool {
        DockPlist.contains(domain.value(forKey: DockPlist.appsKey) as? [DockPlist.Entry] ?? [], path: path, bundleID: bundleID)
    }

    /// Read, change and write `persistent-apps` in one go; the Dock restarts once per batch.
    func modifyDock(_ change: ([DockPlist.Entry]) -> [DockPlist.Entry]) {
        let apps = domain.value(forKey: DockPlist.appsKey) as? [DockPlist.Entry] ?? []
        let updated = change(apps)
        guard !(apps as NSArray).isEqual(to: updated) else { return }
        domain.set(updated, forKey: DockPlist.appsKey)
        domain.commit(restartDock: false)
        scheduleDockRestart()
    }

    private func scheduleDockRestart() {
        guard !restartPending else { return }
        restartPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.flushDockChanges() }
    }

    /// Restarts the Dock now if changes are waiting. The CLI calls this before it exits.
    func flushDockChanges() {
        guard restartPending else { return }
        restartPending = false
        domain.commit(restartDock: true)
    }

    /// Restarts the Dock once so pinned tiles pick up new icons.
    func reloadDock() {
        domain.commit(restartDock: true)
    }

    // MARK: Icons

    private struct Art {
        var image: NSImage
        var clip: Bool
    }

    private func iconArt(_ target: LauncherTarget) -> (Art, String) {
        let lib = store.library
        switch target {
        case .slot(let id):
            guard let slot = lib.slot(id) else { return (Art(image: NSImage(), clip: false), "") }
            let shape = LauncherIcon.shape(for: slot, library: lib)
            let art = IconRenderer.slotIcon(slot, library: lib, size: 1024)
            return (Art(image: art, clip: shape == .squircle || shape == .roundedSquare || shape == .square),
                    LauncherIcon.hash(LauncherIcon.inputs(for: slot, library: lib)))
        case .spacer(let id):
            guard let spacer = lib.spacers.first(where: { $0.id == id }) else { return (Art(image: NSImage(), clip: false), "") }
            return (Art(image: LauncherIcon.spacerArt(spacer), clip: spacer.icon.background != nil), LauncherIcon.hash(spacer))
        }
    }

    /// Custom Finder icon (after signing, so codesign never sees it) plus the PNG the running launcher shows.
    private func applyIcon(_ art: Art, to bundle: URL, id: UUID) {
        let custom = LauncherIcon.compose(art.image, scale: LauncherIcon.customIconScale, clip: art.clip)
        NSWorkspace.shared.setIcon(custom, forFile: bundle.path, options: [])
        NSWorkspace.shared.noteFileSystemChanged(bundle.path)
        let png = LauncherIcon.png(LauncherIcon.compose(art.image, clip: art.clip), pixels: 512)
        let url = PWShared.iconURL(id: id.uuidString)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? png?.write(to: url, options: .atomic)
        DistributedNotificationCenter.default().postNotificationName(
            PWShared.iconChangedNotification, object: id.uuidString, userInfo: nil, deliverImmediately: true)
    }

    private func scheduleIconRefresh() {
        iconWork?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.refreshIcons() } }
        iconWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    /// Re-renders launcher icons whose inputs changed (per-slot hash). Callers debounce.
    func refreshIcons() {
        let lib = store.library
        for slot in lib.slots {
            guard let path = slot.launcherPath, FileManager.default.fileExists(atPath: path), !busy.contains(slot.id) else { continue }
            let (art, hash) = iconArt(.slot(slot.id))
            guard hash != slot.iconHash else { continue }
            applyIcon(art, to: URL(fileURLWithPath: path), id: slot.id)
            store.updateSlot(slot.id, undoable: false) { $0.iconHash = hash }
        }
        for spacer in lib.spacers {
            guard let path = spacer.launcherPath, FileManager.default.fileExists(atPath: path), !busy.contains(spacer.id) else { continue }
            let (art, hash) = iconArt(.spacer(spacer.id))
            guard hash != spacerIconHashes[spacer.id] else { continue }
            applyIcon(art, to: URL(fileURLWithPath: path), id: spacer.id)
            spacerIconHashes[spacer.id] = hash
        }
    }
}

/// Selector-based distributed observer with `.deliverImmediately`, wrapped for a closure.
private final class DistributedRelay: NSObject {
    private let handler: (Notification) -> Void

    init(name: Notification.Name, handler: @escaping (Notification) -> Void) {
        self.handler = handler
        super.init()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(fire(_:)), name: name,
                                                            object: nil, suspensionBehavior: .deliverImmediately)
    }

    @objc private func fire(_ note: Notification) { handler(note) }
}
