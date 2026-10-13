import AppKit
import Observation

/// An installed app as the app drawer shows it.
nonisolated struct AppInfo: Identifiable, Hashable, Sendable {
    var url: URL
    var name: String
    var bundleID: String?
    /// Readable category, e.g. "Developer Tools". nil when the app declares none.
    var category: String?
    var installedAt: Date?
    var id: String { url.path }
}

/// Scans the app folders: each folder plus one level of subfolders. Menu-bar-only apps are skipped on request.
nonisolated enum AppScanner {
    static func scan(paths: [String], skipAgents: Bool) -> [AppInfo] {
        let fm = FileManager.default
        var out: [AppInfo] = []
        var seenBundles = Set<String>()
        var seenPaths = Set<String>()
        for raw in paths {
            let dir = URL(fileURLWithPath: (raw as NSString).expandingTildeInPath, isDirectory: true)
            guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                                                            options: [.skipsHiddenFiles]) else { continue }
            var candidates: [URL] = []
            for e in entries {
                if e.pathExtension == "app" {
                    candidates.append(e)
                } else if (try? e.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                          let sub = try? fm.contentsOfDirectory(at: e, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    candidates += sub.filter { $0.pathExtension == "app" }
                }
            }
            for url in candidates {
                let path = url.resolvingSymlinksInPath().path
                guard seenPaths.insert(path).inserted, let info = read(url, skipAgents: skipAgents) else { continue }
                if let bid = info.bundleID, !seenBundles.insert(bid).inserted { continue }
                out.append(info)
            }
        }
        return out.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func read(_ url: URL, skipAgents: Bool) -> AppInfo? {
        let plist = Bundle(url: url)?.infoDictionary ?? [:]
        if skipAgents && isAgent(plist) { return nil }
        let values = try? url.resourceValues(forKeys: [.addedToDirectoryDateKey, .creationDateKey])
        return AppInfo(url: url,
                       name: FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""),
                       bundleID: plist["CFBundleIdentifier"] as? String,
                       category: (plist["LSApplicationCategoryType"] as? String).flatMap(categoryName),
                       installedAt: values?.addedToDirectoryDate ?? values?.creationDate)
    }

    /// Apps without a Dock icon (menu bar only or background).
    static func isAgent(_ plist: [String: Any]) -> Bool {
        func flag(_ key: String) -> Bool {
            if let b = plist[key] as? Bool { return b }
            if let s = plist[key] as? String { return s == "1" || s.lowercased() == "yes" || s.lowercased() == "true" }
            if let n = plist[key] as? NSNumber { return n.boolValue }
            return false
        }
        return flag("LSUIElement") || flag("LSBackgroundOnly")
    }

    /// "public.app-category.developer-tools" -> "Developer Tools". All game kinds become "Games".
    static func categoryName(_ uti: String) -> String? {
        let prefix = "public.app-category."
        guard uti.hasPrefix(prefix) else { return nil }
        let key = String(uti.dropFirst(prefix.count))
        guard !key.isEmpty else { return nil }
        if key.hasSuffix("-games") || key == "games" { return "Games" }
        let special = ["graphics-design": "Graphics & Design", "healthcare-fitness": "Health & Fitness",
                       "social-networking": "Social Networking", "photography": "Photography"]
        if let s = special[key] { return s }
        return key.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

nonisolated enum AppSort: String, CaseIterable, Sendable {
    case name, recentlyInstalled, category
}

nonisolated enum AppFilter: String, CaseIterable, Sendable {
    case all, notInAnyGroup, recentlyInstalled, inThisGroup
}

nonisolated enum AppQuery {
    /// Search, category, filter and sort for the app drawer.
    static func apply(_ apps: [AppInfo], search: String, categories: Set<String>, filter: AppFilter, sort: AppSort,
                      now: Date = Date(), inGroup: (AppInfo) -> Bool, inAnyGroup: (AppInfo) -> Bool) -> [AppInfo] {
        let q = search.trimmingCharacters(in: .whitespaces)
        var list = apps.filter { app in
            if !q.isEmpty && !app.name.localizedStandardContains(q) && !(app.bundleID?.localizedStandardContains(q) ?? false) {
                return false
            }
            if !categories.isEmpty && !categories.contains(app.category ?? otherCategory) { return false }
            switch filter {
            case .all: return true
            case .notInAnyGroup: return !inAnyGroup(app)
            case .inThisGroup: return inGroup(app)
            case .recentlyInstalled: return app.installedAt.map { now.timeIntervalSince($0) < 30 * 86400 } ?? false
            }
        }
        switch sort {
        case .name:
            list.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .recentlyInstalled:
            list.sort { ($0.installedAt ?? .distantPast) > ($1.installedAt ?? .distantPast) }
        case .category:
            list.sort { ($0.category ?? "~", $0.name.lowercased()) < ($1.category ?? "~", $1.name.lowercased()) }
        }
        return list
    }

    static let otherCategory = "Other"

    static func categories(_ apps: [AppInfo]) -> [String] {
        Set(apps.map { $0.category ?? otherCategory }).sorted { a, b in
            if a == otherCategory { return false }
            if b == otherCategory { return true }
            return a < b
        }
    }
}

/// Installed apps, scanned in the background and kept for the session.
@Observable
final class AppCatalog {
    static let shared = AppCatalog()
    private(set) var apps: [AppInfo] = []
    private(set) var isLoading = false
    @ObservationIgnored private var loadedAt: Date?
    @ObservationIgnored private var running: Task<Void, Never>?

    /// Loads once, then again when older than five minutes (new installs show up).
    func loadIfNeeded() async {
        if let loadedAt, Date().timeIntervalSince(loadedAt) < 300 { return }
        await reload()
    }

    func reload() async {
        // A second caller waits for the scan that is already running.
        if let running { await running.value; return }
        isLoading = true
        let s = LibraryStore.shared.settings
        let paths = s.appSearchPaths
        let skip = s.hideAgentApps
        let task = Task.detached(priority: .userInitiated) { AppScanner.scan(paths: paths, skipAgents: skip) }
        running = Task { _ = await task.value }
        apps = await task.value
        loadedAt = Date()
        isLoading = false
        running = nil
    }
}
