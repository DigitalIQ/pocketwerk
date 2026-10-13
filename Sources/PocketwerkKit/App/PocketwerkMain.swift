import AppKit
import PocketwerkShared

public enum PocketwerkMain {
    public static func run() {
        let app = NSApplication.shared
        let delegate = AppCoordinator()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

/// Wires the modules together. Owned by the orchestrator; modules expose small entry points.
final class AppCoordinator: NSObject, NSApplicationDelegate {
    let store = LibraryStore.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainMenu.install()
        applyActivationPolicy()
        MenuBarController.shared.install()
        HotkeyCenter.shared.start()
        DockManager.shared.start()
        ServicesProvider.shared.register()

        NotificationCenter.default.addObserver(forName: .libraryDidChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { AppCoordinator.current?.applyActivationPolicy() }
        }
        if CommandLine.arguments.contains("--show-window") || store.library.groups.isEmpty {
            MainWindowController.shared.show()
        }
    }

    static var current: AppCoordinator? { NSApp.delegate as? AppCoordinator }

    func applyActivationPolicy() {
        let wanted: NSApplication.ActivationPolicy = store.settings.showMainDockIcon ? .regular : .accessory
        if NSApp.activationPolicy() != wanted { NSApp.setActivationPolicy(wanted) }
    }

    /// Click on the main app's own Dock icon: show every group, swipeable.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        PopupController.shared.toggleAll()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveNow()
    }

    /// pocketwerk://open?slot=<uuid>  pocketwerk://open?group=<uuid>  pocketwerk://add?url=<url>&group=<uuid>
    /// pocketwerk://settings  pocketwerk://profile?id=<uuid>
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { URLRouter.handle(url) }
    }
}

enum URLRouter {
    static func handle(_ url: URL) {
        guard url.scheme == PWShared.urlScheme else {
            // Files dropped on the app icon: add to the first group.
            if url.isFileURL, let first = LibraryStore.shared.library.groups.first {
                LibraryStore.shared.addItems([url], to: first.id)
            }
            return
        }
        let q = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems ?? []).map { ($0.name, $0.value ?? "") })
        switch url.host {
        case "open":
            if let s = q["slot"].flatMap(UUID.init) {
                PopupController.shared.toggle(slotID: s)
            } else if let g = q["group"].flatMap(UUID.init) {
                PopupController.shared.toggle(groupIDs: [g], slotID: nil)
            } else {
                PopupController.shared.toggleAll()
            }
        case "add":
            guard let raw = q["url"], let target = URL(string: raw) else { return }
            let store = LibraryStore.shared
            let groupID = q["group"].flatMap(UUID.init) ?? store.library.groups.first?.id
            if let groupID { store.addItems([target], to: groupID) }
        case "settings":
            MainWindowController.shared.show()
        case "profile":
            if let id = q["id"].flatMap(UUID.init) { DockProfiles.shared.apply(id) }
        default:
            break
        }
    }
}
