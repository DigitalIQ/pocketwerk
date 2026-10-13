import AppKit

/// Computes the items of smart groups. Pure, so the ranking is testable without the real system.
nonisolated enum SmartGroups {
    static func items(_ kind: SmartGroupKind, library: Library, limit: Int,
                      resolveApp: (String) -> URL?, runningApps: [URL]) -> [DockItem] {
        let limit = max(1, limit)
        let pool = uniqueItems(library)
        switch kind {
        case .mostUsed:
            var scored: [(item: DockItem, score: Int)] = pool.map { item in
                let launches = item.bundleID.flatMap { library.usage.launches[$0] } ?? 0
                return (item, item.openCount + launches)
            }
            // Apps launched often that are in no group yet.
            let known = Set(pool.compactMap(\.bundleID))
            for (bid, count) in library.usage.launches where count > 0 && !known.contains(bid) {
                guard let url = resolveApp(bid) else { continue }
                scored.append((appItem(bundleID: bid, url: url), count))
            }
            return Array(scored.filter { $0.score > 0 }
                .sorted { a, b in
                    if a.score != b.score { return a.score > b.score }
                    return a.item.displayName.localizedStandardCompare(b.item.displayName) == .orderedAscending
                }
                .map(\.item).prefix(limit))

        case .recentlyOpened:
            var dated: [(item: DockItem, date: Date)] = pool.compactMap { item in
                let launch = item.bundleID.flatMap { library.usage.lastLaunch[$0] }
                guard let date = [item.lastOpenedAt, launch].compactMap({ $0 }).max() else { return nil }
                return (item, date)
            }
            let known = Set(pool.compactMap(\.bundleID))
            for (bid, date) in library.usage.lastLaunch where !known.contains(bid) {
                guard let url = resolveApp(bid) else { continue }
                dated.append((appItem(bundleID: bid, url: url), date))
            }
            return Array(dated.sorted { $0.date > $1.date }.map(\.item).prefix(limit))

        case .runningApps:
            return runningApps.map { url in
                pool.first { $0.kind == .app && $0.url.standardizedFileURL == url.standardizedFileURL }
                    ?? appItem(bundleID: nil, url: url)
            }
        }
    }

    /// Items of all regular groups, first occurrence wins (apps matched by bundle ID, others by URL).
    static func uniqueItems(_ library: Library) -> [DockItem] {
        var seen = Set<String>()
        return library.groups.filter { $0.smart == nil }.flatMap(\.items).filter { item in
            seen.insert(item.bundleID ?? item.url.absoluteString).inserted
        }
    }

    /// An app item with an id derived from its bundle ID or path, so lists keep their identity.
    static func appItem(bundleID: String?, url: URL) -> DockItem {
        var item = DockItem(kind: .app, url: url)
        if let bundleID { item.bundleID = bundleID }
        item.id = stableID(bundleID ?? url.path)
        return item
    }

    /// Deterministic UUID from a string (FNV-1a, 128 bit).
    static func stableID(_ key: String) -> UUID {
        var h1: UInt64 = 0xcbf2_9ce4_8422_2325
        var h2: UInt64 = 0x8422_2325_cbf2_9ce4
        for b in key.utf8 {
            h1 = (h1 ^ UInt64(b)) &* 0x0000_0100_0000_01B3
            h2 = (h2 ^ UInt64(b)) &* 0x0000_0100_0000_01B3 &+ 0x9E37
        }
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 { bytes[i] = UInt8(truncatingIfNeeded: h1 >> (UInt64(i) * 8)) }
        for i in 0..<8 { bytes[8 + i] = UInt8(truncatingIfNeeded: h2 >> (UInt64(i) * 8)) }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    static func title(_ kind: SmartGroupKind) -> String {
        switch kind {
        case .mostUsed: String(localized: "Most Used")
        case .recentlyOpened: String(localized: "Recently Opened")
        case .runningApps: String(localized: "Running Apps")
        }
    }

    static func symbol(_ kind: SmartGroupKind) -> String {
        switch kind {
        case .mostUsed: "star.fill"
        case .recentlyOpened: "clock.arrow.circlepath"
        case .runningApps: "play.circle"
        }
    }
}

/// Finds apps by bundle ID and caches the answer for the session.
enum AppLocator {
    private static var cache: [String: URL?] = [:]

    static func url(forBundleID id: String) -> URL? {
        if let hit = cache[id] { return hit }
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
        cache[id] = url
        return url
    }

    static func forget() { cache.removeAll() }
}

extension LibraryStore {
    /// Live items of a smart group (used by `visibleItems`).
    func smartItems(_ kind: SmartGroupKind, limit: Int) -> [DockItem] {
        let running: [URL] = kind == .runningApps
            ? NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
                .compactMap(\.bundleURL)
            : []
        return SmartGroups.items(kind, library: library, limit: limit,
                                 resolveApp: { AppLocator.url(forBundleID: $0) }, runningApps: running)
    }

    /// Counts an app launch seen anywhere on the system. Not undoable.
    func recordLaunch(bundleID: String, at date: Date = Date()) {
        mutate(undoable: false) { lib in
            UsageTracker.record(bundleID: bundleID, at: date, in: &lib.usage)
        }
    }
}

/// Passive launch counting via NSWorkspace notifications. No permissions needed.
final class UsageTracker {
    static let shared = UsageTracker()
    private var observer: NSObjectProtocol?

    func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bid = app?.bundleIdentifier
            let regular = app?.activationPolicy == .regular
            MainActor.assumeIsolated {
                guard let bid, regular, UsageTracker.counts(bid) else { return }
                LibraryStore.shared.recordLaunch(bundleID: bid)
            }
        }
    }

    /// System helpers and Pocketwerk itself are not counted.
    nonisolated static func counts(_ bundleID: String) -> Bool {
        !bundleID.hasPrefix("io.github.digitaliq.pocketwerk")
            && bundleID != "com.apple.finder" && bundleID != "com.apple.dock"
            && !bundleID.hasPrefix("com.apple.loginwindow")
    }

    /// Adds one launch. Apps launched within 10 minutes of each other count as used together.
    nonisolated static func record(bundleID: String, at date: Date, in usage: inout UsageStats) {
        usage.launches[bundleID, default: 0] += 1
        for (other, last) in usage.lastLaunch where other != bundleID && date.timeIntervalSince(last) < 600 {
            usage.coOccurrence[bundleID, default: [:]][other, default: 0] += 1
            usage.coOccurrence[other, default: [:]][bundleID, default: 0] += 1
        }
        usage.lastLaunch[bundleID] = date
    }
}
