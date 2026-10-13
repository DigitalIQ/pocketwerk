import AppKit

/// The main app's own Dock tile shows a live mini grid of the first group.
/// Drawn through `NSDockTile.contentView`, so `NSApp.applicationIconImage` (used in About and
/// onboarding) keeps the real app icon.
final class MainDockTile {
    static let shared = MainDockTile()

    private var lastHash: String?
    private var pending: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []

    func start() {
        guard observers.isEmpty else { return }
        observers.append(NotificationCenter.default.addObserver(forName: .libraryDidChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { MainDockTile.shared.scheduleUpdate() }
        })
        // New favicons change the grid without changing the library.
        observers.append(NotificationCenter.default.addObserver(forName: .itemIconsDidChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                MainDockTile.shared.lastHash = nil
                MainDockTile.shared.scheduleUpdate()
            }
        })
        update()
    }

    private func scheduleUpdate() {
        pending?.cancel()
        let work = DispatchWorkItem { MainActor.assumeIsolated { MainDockTile.shared.update() } }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func update() {
        let store = LibraryStore.shared
        let settings = store.settings
        guard settings.liveMainDockIcon, settings.showMainDockIcon, let group = store.library.orderedGroups.first else {
            reset()
            return
        }
        let hash = LauncherIcon.hash(LauncherIcon.GroupInputs(
            name: group.name, icon: group.icon, background: group.style.background,
            items: Array(group.sortedItems.prefix(16).map(\.url))))
        guard hash != lastHash, let data = IconRenderer.pngData(for: group, size: 512), let image = NSImage(data: data) else { return }
        lastHash = hash
        let view = NSImageView(image: image)
        view.imageScaling = .scaleProportionallyUpOrDown
        NSApp.dockTile.contentView = view
        NSApp.dockTile.display()
    }

    private func reset() {
        lastHash = nil
        guard NSApp.dockTile.contentView != nil else { return }
        NSApp.dockTile.contentView = nil
        NSApp.dockTile.display()
    }
}
