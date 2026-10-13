import AppKit
import Observation

/// Opens, hides and quits group items through NSWorkspace. No Accessibility permission needed.
enum ItemOpener {
    /// Opens an app, file, folder or link and records usage.
    /// A running app is unhidden and brought to front; it also gets the reopen event,
    /// so most apps restore a minimized or closed window like a Dock click does.
    static func open(_ item: DockItem, in groupID: UUID) {
        switch item.kind {
        case .app:
            let url = appURL(for: item)
            if let running = RunningApps.shared.app(for: item) { running.unhide() }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config)
        case .file, .folder, .link:
            NSWorkspace.shared.open(item.url)
        }
        let store = LibraryStore.shared
        store.recordOpen(item.id, in: store.owningGroupID(of: item.id, fallback: groupID))
    }

    /// Opens every item of a group.
    static func openAll(_ group: ItemGroup) {
        open(LibraryStore.shared.visibleItems(of: group), in: group.id)
    }

    /// Opens items one after another with the "Open All" delay, so macOS does not stall.
    /// Each app comes to the front when it is ready.
    static func open(_ items: [DockItem], in groupID: UUID) {
        let delay = max(LibraryStore.shared.settings.openAllDelay, 0)
        Task { @MainActor in
            for (n, item) in items.enumerated() {
                if n > 0, delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
                open(item, in: groupID)
            }
        }
    }

    /// Opens files with a given app item (drop onto an app tile, "Open With").
    static func open(_ files: [URL], withApp app: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(files, withApplicationAt: app, configuration: config)
    }

    static func revealInFinder(_ items: [DockItem]) {
        let urls = items.filter { $0.kind != .link }.map { $0.kind == .app ? appURL(for: $0) : $0.url }
        if !urls.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(urls) }
    }

    // MARK: Running apps

    /// Hides every running app of the list, the frontmost one too.
    static func hideAll(_ items: [DockItem]) {
        for app in runningApps(items) { app.hide() }
    }

    /// Quits every running app of the list. Graceful quit lets apps ask to save.
    static func quitAll(_ items: [DockItem], force: Bool) {
        for app in runningApps(items) {
            if force { app.forceTerminate() } else { app.terminate() }
        }
    }

    static func hide(_ item: DockItem) { RunningApps.shared.app(for: item)?.hide() }

    static func quit(_ item: DockItem, force: Bool = false) {
        guard let app = RunningApps.shared.app(for: item) else { return }
        if force { app.forceTerminate() } else { app.terminate() }
    }

    static func runningApps(_ items: [DockItem]) -> [NSRunningApplication] {
        items.filter { $0.kind == .app }.compactMap { RunningApps.shared.app(for: $0) }
    }

    /// The app's current location: bundle ID first, so an item survives when the app moves.
    static func appURL(for item: DockItem) -> URL {
        if let id = item.bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { return url }
        return item.url
    }
}

/// Live set of running apps for the indicator dots. Fed by NSWorkspace notifications.
@Observable
final class RunningApps {
    static let shared = RunningApps()

    private(set) var bundleIDs: Set<String> = []
    private(set) var paths: Set<String> = []
    @ObservationIgnored private var started = false

    init() {}

    func start() {
        guard !started else { return }
        started = true
        refresh()
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { RunningApps.shared.refresh() }
            }
        }
    }

    func refresh() {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy != .prohibited }
        let ids = Set(apps.compactMap(\.bundleIdentifier))
        let p = Set(apps.compactMap { $0.bundleURL?.standardizedFileURL.path })
        if ids != bundleIDs { bundleIDs = ids }
        if p != paths { paths = p }
    }

    func isRunning(_ item: DockItem) -> Bool {
        guard item.kind == .app else { return false }
        if !started { start() }
        if let id = item.bundleID { return bundleIDs.contains(id) }
        return paths.contains(item.url.standardizedFileURL.path)
    }

    func app(for item: DockItem) -> NSRunningApplication? {
        guard item.kind == .app else { return nil }
        if let id = item.bundleID {
            return NSRunningApplication.runningApplications(withBundleIdentifier: id).first
        }
        let path = item.url.standardizedFileURL.path
        return NSWorkspace.shared.runningApplications.first { $0.bundleURL?.standardizedFileURL.path == path }
    }
}
