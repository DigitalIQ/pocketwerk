import AppKit
import Observation

/// Finds items whose app, file or folder is gone. Apps are looked up by bundle ID first, then by path.
nonisolated enum MissingItems {
    struct Result: Equatable, Sendable {
        /// Apps that moved: new location found by bundle ID.
        var relinked: [UUID: URL] = [:]
        var missing: Set<UUID> = []
    }

    static func check(_ items: [DockItem], locate: (String) -> URL?, exists: (String) -> Bool) -> Result {
        var r = Result()
        for item in items where item.kind != .link {
            if item.kind == .app, let bid = item.bundleID, let found = locate(bid) {
                if !exists(item.url.path) && found.standardizedFileURL != item.url.standardizedFileURL {
                    r.relinked[item.id] = found
                }
                continue
            }
            if !exists(item.url.path) { r.missing.insert(item.id) }
        }
        return r
    }
}

/// Keeps the set of missing items up to date in the background and relinks moved apps.
@Observable
final class LibraryHealth {
    static let shared = LibraryHealth()

    private(set) var missing: Set<UUID> = []
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var observer: NSObjectProtocol?

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: .libraryDidChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { LibraryHealth.shared.scheduleScan(delay: 1.5) }
        }
        scheduleScan(delay: 2)
    }

    /// Scans off the main thread after a short pause, so typing and dragging stay smooth.
    func scheduleScan(delay: Double = 0) {
        task?.cancel()
        let items = LibraryStore.shared.library.groups.filter { $0.smart == nil }.flatMap(\.items)
        task = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            let result = await Task.detached(priority: .utility) {
                MissingItems.check(items,
                                   locate: { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) },
                                   exists: { FileManager.default.fileExists(atPath: $0) })
            }.value
            guard !Task.isCancelled else { return }
            self?.apply(result)
        }
    }

    private func apply(_ result: MissingItems.Result) {
        let store = LibraryStore.shared
        if !result.relinked.isEmpty {
            store.mutate(undoable: false) { lib in
                for g in lib.groups.indices {
                    for i in lib.groups[g].items.indices {
                        if let url = result.relinked[lib.groups[g].items[i].id] { lib.groups[g].items[i].url = url }
                    }
                }
            }
        }
        if store.settings.removeMissingItems && !result.missing.isEmpty {
            store.mutate(undoable: false) { lib in
                for g in lib.groups.indices { lib.groups[g].items.removeAll { result.missing.contains($0.id) } }
            }
            missing = []
            return
        }
        if missing != result.missing { missing = result.missing }
    }

    /// "Remove Missing Items" button. Undoable.
    func removeMissing() {
        let ids = missing
        guard !ids.isEmpty else { return }
        LibraryStore.shared.mutate { lib in
            for g in lib.groups.indices { lib.groups[g].items.removeAll { ids.contains($0.id) } }
        }
        missing = []
    }
}
