import Foundation

/// A copy of the Dock keys a profile stores, as a property list dictionary. Pure helpers.
nonisolated enum DockSnapshot {
    typealias Entry = DockPlist.Entry
    typealias Values = [String: Any]

    static func encode(_ values: Values) -> Data {
        (try? PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)) ?? Data()
    }

    static func decode(_ data: Data) -> Values {
        guard !data.isEmpty,
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? Values else { return [:] }
        return dict
    }

    static func apps(_ values: Values) -> [Entry] { values[DockPlist.appsKey] as? [Entry] ?? [] }
    static func others(_ values: Values) -> [Entry] { values[DockPlist.othersKey] as? [Entry] ?? [] }

    /// True when the Dock could not be read or has no tiles at all.
    static func isEmpty(_ values: Values) -> Bool { apps(values).isEmpty && others(values).isEmpty }

    /// Structured tiles for the editor, apps first, then the section right of the divider.
    static func tiles(from values: Values) -> [DockTile] {
        apps(values).compactMap { DockPlist.tile(from: $0, isOther: false) }
            + others(values).compactMap { DockPlist.tile(from: $0, isOther: true) }
    }

    /// Order-sensitive identity of all tiles. Equal signatures mean the Dock shows the same tiles.
    static func signature(_ values: Values) -> [String] {
        apps(values).map(DockPlist.identity(of:)) + ["|divider|"] + others(values).map(DockPlist.identity(of:))
    }

    /// Bundle ids and paths of every app tile.
    static func appTargets(_ values: Values) -> [(bundleID: String?, path: String)] {
        apps(values).compactMap { e in
            guard DockPlist.tileType(e) == "file-tile", let path = DockPlist.path(of: e), path.hasSuffix(".app") else { return nil }
            return (DockPlist.bundleID(of: e), path)
        }
    }

    /// Writes edited tiles back into the raw values. Entries of unchanged tiles are reused, so the
    /// Dock's own data (bookmarks, GUIDs) stays; Dock settings keys are kept as they are.
    static func rebuild(_ values: Values, tiles: [DockTile]) -> Values {
        var out = values
        var pool = apps(values) + others(values)
        func entry(for tile: DockTile) -> Entry? {
            guard var built = DockPlist.entry(for: tile) else { return nil }
            let id = DockPlist.identity(of: built)
            if !tile.kind.isSpacer, let i = pool.firstIndex(where: { DockPlist.identity(of: $0) == id }) {
                var reused = pool.remove(at: i)
                var data = DockPlist.tileData(reused)
                let newData = DockPlist.tileData(built)
                for key in ["file-label", "label", "arrangement", "displayas", "showas"] where newData[key] != nil {
                    data[key] = newData[key]
                }
                reused["tile-data"] = data
                built = reused
            }
            return built
        }
        // Entry types the editor does not show stay in their section.
        let unknownApps = apps(values).filter { DockPlist.tile(from: $0, isOther: false) == nil }
        let unknownOthers = others(values).filter { DockPlist.tile(from: $0, isOther: true) == nil }
        out[DockPlist.appsKey] = tiles.filter { !$0.isOther }.compactMap(entry) + unknownApps
        out[DockPlist.othersKey] = tiles.filter(\.isOther).compactMap(entry) + unknownOthers
        return out
    }

    /// Drops entries whose file is gone (they would show as "?" tiles). Apps that moved are found
    /// again by bundle id. Returns the cleaned values and the labels of what was dropped.
    static func removingMissing(_ values: Values, exists: (String) -> Bool,
                                locate: (String) -> String?) -> (values: Values, missing: [String]) {
        var missing: [String] = []
        func clean(_ entries: [Entry]) -> [Entry] {
            entries.compactMap { e in
                guard let path = DockPlist.path(of: e), !exists(path) else { return e }
                if let bid = DockPlist.bundleID(of: e), let moved = locate(bid), exists(moved) {
                    return DockPlist.replacingPath(e, path: moved, label: DockPlist.label(of: e) ?? DockPlist.defaultLabel(for: URL(fileURLWithPath: moved)))
                }
                missing.append(DockPlist.label(of: e) ?? path)
                return nil
            }
        }
        var out = values
        out[DockPlist.appsKey] = clean(apps(values))
        out[DockPlist.othersKey] = clean(others(values))
        return (out, missing)
    }
}

extension TileKind {
    nonisolated var isSpacer: Bool { self == .spacer || self == .smallSpacer || self == .flexSpacer }
}
