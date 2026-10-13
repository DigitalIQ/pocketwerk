import AppKit
import PocketwerkShared

// MARK: - Domain

/// The `com.apple.dock` preference domain, behind a protocol so tests and development runs
/// never touch the real Dock.
protocol DockDomain: AnyObject {
    func value(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    /// Writes pending changes. With `restartDock` the Dock reloads them (one restart per batch).
    func commit(restartDock: Bool)
}

/// The real Dock, through CFPreferences. Never write the plist file directly: cfprefsd caches it.
final class SystemDockDomain: DockDomain {
    private let domain = "com.apple.dock" as CFString

    func value(forKey key: String) -> Any? {
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue(key as CFString, domain)
    }

    func set(_ value: Any?, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, value as CFPropertyList?, domain)
    }

    func commit(restartDock: Bool) {
        CFPreferencesAppSynchronize(domain)
        guard restartDock else { return }
        // launchd starts the Dock again right away and it reads the new values.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = ["Dock"]
        try? p.run()
    }
}

/// A plist file standing in for the Dock. Used when $POCKETWERK_DOCK_PLIST is set (development runs).
final class FileDockDomain: DockDomain {
    let url: URL
    private var values: [String: Any]
    private(set) var restartCount = 0

    init(url: URL) {
        self.url = url
        if let data = try? Data(contentsOf: url),
           let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            values = dict
        } else {
            values = [:]
        }
    }

    func value(forKey key: String) -> Any? { values[key] }

    func set(_ value: Any?, forKey key: String) { values[key] = value }

    func commit(restartDock: Bool) {
        if let data = try? PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0) {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
        if restartDock { restartCount += 1 }
    }
}

enum DockDomains {
    /// The real Dock, or a file when $POCKETWERK_DOCK_PLIST is set.
    static func makeDefault() -> DockDomain {
        if let path = ProcessInfo.processInfo.environment["POCKETWERK_DOCK_PLIST"], !path.isEmpty {
            return FileDockDomain(url: URL(fileURLWithPath: path))
        }
        return SystemDockDomain()
    }
}

// MARK: - Entries

/// Builds and parses `persistent-apps` / `persistent-others` entries. Pure functions.
nonisolated enum DockPlist {
    typealias Entry = [String: Any]

    static let appsKey = "persistent-apps"
    static let othersKey = "persistent-others"
    /// Dock settings saved with a profile besides the tiles.
    static let settingKeys = ["tilesize", "largesize", "magnification", "orientation", "autohide",
                              "show-recents", "mineffect", "minimize-to-application"]
    static var profileKeys: [String] { [appsKey, othersKey] + settingKeys }

    // MARK: Building

    static func fileData(path: String, isDirectory: Bool) -> Entry {
        ["_CFURLString": URL(fileURLWithPath: path, isDirectory: isDirectory).absoluteString, "_CFURLStringType": 15]
    }

    static func appTile(path: String, label: String, bundleID: String?) -> Entry {
        var data: Entry = ["file-data": fileData(path: path, isDirectory: true), "file-label": label, "file-type": 41]
        if let bundleID { data["bundle-identifier"] = bundleID }
        return ["tile-type": "file-tile", "tile-data": data, "GUID": newGUID()]
    }

    static func fileTile(path: String, label: String) -> Entry {
        ["tile-type": "file-tile",
         "tile-data": ["file-data": fileData(path: path, isDirectory: false), "file-label": label, "file-type": 41] as Entry,
         "GUID": newGUID()]
    }

    static func folderTile(path: String, label: String, stack: StackSettings) -> Entry {
        ["tile-type": "directory-tile",
         "tile-data": ["directory": 1, "file-data": fileData(path: path, isDirectory: true), "file-label": label,
                       "file-type": 2, "arrangement": stack.sort, "displayas": stack.displayAs, "showas": stack.view] as Entry,
         "GUID": newGUID()]
    }

    static func urlTile(url: URL, label: String) -> Entry {
        ["tile-type": "url-tile",
         "tile-data": ["label": label, "url": ["_CFURLString": url.absoluteString, "_CFURLStringType": 15] as Entry] as Entry,
         "GUID": newGUID()]
    }

    static func spacerTile(_ kind: TileKind) -> Entry {
        let type = switch kind {
        case .smallSpacer: "small-spacer-tile"
        case .flexSpacer: "flex-spacer-tile"
        default: "spacer-tile"
        }
        return ["tile-type": type, "tile-data": Entry(), "GUID": newGUID()]
    }

    /// Entry for an editor tile. nil when the tile has nothing to point at.
    static func entry(for tile: DockTile) -> Entry? {
        let label = tile.label ?? tile.url.map { defaultLabel(for: $0) } ?? ""
        switch tile.kind {
        case .app, .customSpacer:
            guard let url = tile.url else { return nil }
            return appTile(path: url.path, label: label, bundleID: tile.bundleID)
        case .file:
            guard let url = tile.url else { return nil }
            return fileTile(path: url.path, label: label)
        case .folder:
            guard let url = tile.url else { return nil }
            return folderTile(path: url.path, label: label, stack: tile.folder ?? StackSettings())
        case .url:
            guard let url = tile.url else { return nil }
            return urlTile(url: url, label: label)
        case .spacer, .smallSpacer, .flexSpacer:
            return spacerTile(tile.kind)
        }
    }

    static func defaultLabel(for url: URL) -> String {
        guard url.isFileURL else { return url.host(percentEncoded: false) ?? url.absoluteString }
        let name = url.lastPathComponent
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    private static func newGUID() -> Int { Int.random(in: 100_000_000...2_000_000_000) }

    // MARK: Parsing

    static func tileType(_ entry: Entry) -> String { entry["tile-type"] as? String ?? "" }

    static func tileData(_ entry: Entry) -> Entry { entry["tile-data"] as? Entry ?? [:] }

    /// Converts `_CFURLString` (a file URL, or a plain path when `_CFURLStringType` is 0) to a path.
    static func path(fromURLData data: Entry?) -> String? {
        guard let s = data?["_CFURLString"] as? String, !s.isEmpty else { return nil }
        let type = (data?["_CFURLStringType"] as? Int) ?? 15
        if type == 0 || s.hasPrefix("/") {
            return (s as NSString).standardizingPath
        }
        guard let url = URL(string: s), url.isFileURL else { return nil }
        return url.standardizedFileURL.path(percentEncoded: false).trimmingTrailingSlash
    }

    /// File path an entry points to (apps, files, folders). nil for links and spacers.
    static func path(of entry: Entry) -> String? {
        path(fromURLData: tileData(entry)["file-data"] as? Entry)
    }

    static func bundleID(of entry: Entry) -> String? {
        tileData(entry)["bundle-identifier"] as? String
    }

    static func label(of entry: Entry) -> String? {
        let data = tileData(entry)
        return data["file-label"] as? String ?? data["label"] as? String
    }

    /// Structured tile for the profile editor. nil for tile types the editor does not know (they stay in the raw data).
    static func tile(from entry: Entry, isOther: Bool) -> DockTile? {
        let data = tileData(entry)
        switch tileType(entry) {
        case "file-tile":
            guard let path = path(of: entry) else { return nil }
            let url = URL(fileURLWithPath: path)
            let bid = bundleID(of: entry)
            let kind: TileKind
            if let bid, bid.hasPrefix(PWShared.spacerBundleIDPrefix) { kind = .customSpacer }
            else if path.hasSuffix(".app") { kind = .app }
            else { kind = .file }
            return DockTile(kind: kind, url: url, bundleID: bid, label: label(of: entry), isOther: isOther)
        case "directory-tile":
            guard let path = path(of: entry) else { return nil }
            var t = DockTile(kind: .folder, url: URL(fileURLWithPath: path, isDirectory: true), label: label(of: entry), isOther: isOther)
            t.folder = StackSettings(view: data["showas"] as? Int ?? 0, displayAs: data["displayas"] as? Int ?? 0,
                                     sort: data["arrangement"] as? Int ?? 1)
            return t
        case "url-tile":
            guard let s = (data["url"] as? Entry)?["_CFURLString"] as? String, let url = URL(string: s) else { return nil }
            return DockTile(kind: .url, url: url, label: data["label"] as? String, isOther: isOther)
        case "spacer-tile": return DockTile(kind: .spacer, isOther: isOther)
        case "small-spacer-tile": return DockTile(kind: .smallSpacer, isOther: isOther)
        case "flex-spacer-tile": return DockTile(kind: .flexSpacer, isOther: isOther)
        default: return nil
        }
    }

    /// Identity used to match entries: same kind and same target. Spacers match by kind only.
    static func identity(of entry: Entry) -> String {
        let type = tileType(entry)
        if type == "url-tile" {
            return "url|" + (((tileData(entry)["url"] as? Entry)?["_CFURLString"] as? String) ?? "")
        }
        return type + "|" + (path(of: entry) ?? "")
    }

    static func identity(of tile: DockTile) -> String {
        entry(for: tile).map { identity(of: $0) } ?? ""
    }

    // MARK: Launcher tiles

    /// True when an entry points to `path` or carries `bundleID`.
    static func matches(_ entry: Entry, path: String?, bundleID: String?) -> Bool {
        if let bundleID, Self.bundleID(of: entry) == bundleID { return true }
        if let path, let own = Self.path(of: entry) {
            return own == (path as NSString).standardizingPath.trimmingTrailingSlash
        }
        return false
    }

    static func contains(_ entries: [Entry], path: String?, bundleID: String?) -> Bool {
        entries.contains { matches($0, path: path, bundleID: bundleID) }
    }

    /// Appends an app tile unless one for the same path or bundle id exists. Moved bundles get their path updated.
    static func adding(app path: String, label: String, bundleID: String?, to entries: [Entry]) -> [Entry] {
        var out = entries
        if let i = out.firstIndex(where: { matches($0, path: path, bundleID: bundleID) }) {
            out[i] = replacingPath(out[i], path: path, label: label)
            return out
        }
        out.append(appTile(path: path, label: label, bundleID: bundleID))
        return out
    }

    static func removing(path: String?, bundleID: String?, from entries: [Entry]) -> [Entry] {
        entries.filter { !matches($0, path: path, bundleID: bundleID) }
    }

    /// Points an existing app tile to a new path (renamed launcher) and keeps its position.
    static func replacingPath(_ entry: Entry, path: String, label: String) -> Entry {
        guard self.path(of: entry) != path || Self.label(of: entry) != label else { return entry }
        var data = tileData(entry)
        data["file-data"] = fileData(path: path, isDirectory: true)
        data["file-label"] = label
        // Cached bookmark data points at the old path; the Dock rebuilds it.
        data.removeValue(forKey: "book")
        var e = entry
        e["tile-data"] = data
        return e
    }
}

private extension String {
    nonisolated var trimmingTrailingSlash: String {
        count > 1 && hasSuffix("/") ? String(dropLast()) : self
    }
}
