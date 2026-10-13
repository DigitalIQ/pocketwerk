import AppKit
import os
import PocketwerkShared

// Tiny resident app behind one Dock tile. It never shows a window. A click on the tile
// is forwarded to the main app; files dropped on the tile are forwarded too.

let launcherLog = Logger(subsystem: "io.github.digitaliq.pocketwerk.launcher", category: "launcher")

final class LauncherDelegate: NSObject, NSApplicationDelegate {
    /// Slot UUID (or spacer UUID for spacer tiles).
    let id = Bundle.main.object(forInfoDictionaryKey: PWShared.slotInfoKey) as? String ?? ""
    let isSpacer = (Bundle.main.object(forInfoDictionaryKey: PWShared.kindInfoKey) as? String) == "spacer"
    private var lastForward = Date.distantPast
    private lazy var menuBuilder = LauncherDockMenu(slotID: id)

    func applicationDidFinishLaunching(_ note: Notification) {
        // Activation policy: the bundle declares LSUIElement and stays `.accessory` while running.
        // Both variants were run as real bundles on macOS 27 (LSUIElement, and a regular bundle that
        // switches to `.accessory` in didFinishLaunching). Both stay resident and both receive the
        // reopen event (`open` and the AppleScript reopen command, which is what a tile click sends).
        // The regular variant stays registered as a "Foreground" app after the switch: it keeps an
        // extra Dock tile and a Cmd-Tab entry. LSUIElement is a "UIElement" from the first frame,
        // with no extra tile, no Cmd-Tab entry and no launch bounce, so it is the variant we ship.
        // The call below only guards against a template that lost the key.
        if NSApp.activationPolicy() != .accessory { NSApp.setActivationPolicy(.accessory) }

        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(iconChanged(_:)), name: PWShared.iconChangedNotification,
                           object: id, suspensionBehavior: .deliverImmediately)
        center.addObserver(self, selector: #selector(quitRequested(_:)), name: PWShared.launcherQuitNotification,
                           object: id, suspensionBehavior: .deliverImmediately)
        loadIcon()
        watchIcons()

        let isDefaultLaunch = (note.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool) ?? true
        launcherLog.notice("launched id=\(self.id, privacy: .public) default=\(isDefaultLaunch) policy=\(NSApp.activationPolicy().rawValue)")
        if isDefaultLaunch, !CommandLine.arguments.contains(PWShared.quietLaunchArgument) {
            forwardClick()
        }
    }

    /// A click on the Dock tile of the running launcher.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        launcherLog.notice("reopen id=\(self.id, privacy: .public)")
        forwardClick(spring: Self.isDragging)
        return false
    }

    /// Spring-loading: a drag resting on the tile activates the app while the mouse button is still
    /// down. The main app then shows the popup (without toggling it) so the drop can land inside.
    func applicationDidBecomeActive(_ notification: Notification) {
        guard Self.isDragging else { return }
        launcherLog.notice("spring id=\(self.id, privacy: .public)")
        forwardClick(spring: true)
    }

    private static var isDragging: Bool { NSEvent.pressedMouseButtons & 1 != 0 }

    /// Files dropped on the tile.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard !isSpacer, !urls.isEmpty else { return }
        launcherLog.notice("drop count=\(urls.count)")
        open(PWShared.addURL(slotID: id, urls: urls))
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        isSpacer ? nil : menuBuilder.menu()
    }

    // MARK: Click

    private func forwardClick(spring: Bool = false) {
        loadIcon(force: false)
        guard !isSpacer else { return }
        // The Dock can deliver launch and reopen for one click; drop the second.
        guard Date().timeIntervalSince(lastForward) > 0.25 else { return }
        lastForward = Date()
        let point = NSEvent.mouseLocation
        let mains = NSRunningApplication.runningApplications(withBundleIdentifier: PWShared.mainBundleID)
        if let main = mains.first {
            DistributedNotificationCenter.default().postNotificationName(
                PWShared.openSlotNotification, object: id,
                userInfo: [PWShared.xKey: Double(point.x), PWShared.yKey: Double(point.y),
                           PWShared.timeKey: Date().timeIntervalSince1970, PWShared.springKey: spring],
                deliverImmediately: true)
            // Lets the main app take key focus for its popup.
            NSApp.yieldActivation(to: main)
        } else if !spring {
            open(PWShared.openURL(slotID: id, at: point))
        }
    }

    /// Opens a pocketwerk:// URL without bringing anything to the front.
    private func open(_ url: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        if let path = Bundle.main.object(forInfoDictionaryKey: PWShared.mainAppPathInfoKey) as? String,
           !path.isEmpty, FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open([url], withApplicationAt: URL(fileURLWithPath: path), configuration: config)
        } else {
            NSWorkspace.shared.open(url, configuration: config)
        }
    }

    // MARK: Icon

    @objc private func iconChanged(_ note: Notification) { loadIcon(force: true) }

    @objc private func quitRequested(_ note: Notification) { NSApp.terminate(nil) }

    /// Modification date of the PNG last shown, so a reload only happens when it changed.
    private var iconDate: Date?
    private var iconWatcher: DispatchSourceFileSystemObject?

    /// Shows the current icon PNG. `force` reloads even when the file date did not change.
    private func loadIcon(force: Bool = true) {
        let url = PWShared.iconURL(id: id)
        let date = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
        guard force || date != iconDate else { return }
        guard let data = try? Data(contentsOf: url), let image = NSImage(data: data) else { return }
        iconDate = date
        NSApp.applicationIconImage = image
        NSApp.dockTile.display()
    }

    /// Watches the icons folder too, in case a notification was missed while the launcher was busy.
    private func watchIcons() {
        let folder = PWShared.iconsFolder()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fd = Darwin.open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename], queue: .main)
        source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.loadIcon(force: false) } }
        source.setCancelHandler { Darwin.close(fd) }
        source.resume()
        iconWatcher = source
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = LauncherDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
