import AppKit
import SwiftUI

// Ordering, membership and editing helpers used by the main window, menu bar and hotkeys.

nonisolated extension Library {
    /// Sidebar order: pinned groups first, otherwise the stored order.
    var orderedGroups: [ItemGroup] { groups.filter(\.pinned) + groups.filter { !$0.pinned } }

    /// Groups the "all groups" carousel and the menu bar show.
    var carouselGroups: [ItemGroup] {
        orderedGroups.filter { g in
            !g.hiddenFromAll && !(g.smart == .mostUsed && !settings.showMostUsed)
        }
    }

    /// Groups that store their own items (no smart groups), in sidebar order.
    var regularGroups: [ItemGroup] { orderedGroups.filter { $0.smart == nil } }

    /// True when any regular group holds this app (bundle ID first, then path).
    func anyGroupContains(appURL: URL, bundleID: String?) -> Bool {
        groups.contains { $0.smart == nil && $0.indexOfApp(url: appURL, bundleID: bundleID) != nil }
    }
}

nonisolated extension ItemGroup {
    /// Position of an app in `items`, matched by bundle ID first, then by path.
    func indexOfApp(url: URL, bundleID: String?) -> Int? {
        if let bundleID, let i = items.firstIndex(where: { $0.bundleID == bundleID }) { return i }
        return items.firstIndex { $0.url.standardizedFileURL == url.standardizedFileURL }
    }

    /// Same item already in the group (bundle ID for apps, URL for the rest).
    func indexOfMatch(_ item: DockItem) -> Int? {
        if item.kind == .app { return indexOfApp(url: item.url, bundleID: item.bundleID) }
        return items.firstIndex { $0.url == item.url }
    }
}

nonisolated enum GroupOrdering {
    /// Applies a drag in the sidebar (indices refer to `orderedGroups`) and returns the new stored order.
    /// Pinned groups always stay above unpinned ones.
    static func move(_ lib: Library, from source: IndexSet, to destination: Int) -> [ItemGroup] {
        var shown = lib.orderedGroups
        shown.move(fromOffsets: source, toOffset: destination)
        return shown.filter(\.pinned) + shown.filter { !$0.pinned }
    }

    /// Moves one item to `index` of the shown (sorted) list. The shown order becomes the manual order.
    static func reorder(_ group: ItemGroup, itemID: UUID, to index: Int) -> [DockItem] {
        var shown = group.sortedItems
        guard let from = shown.firstIndex(where: { $0.id == itemID }) else { return group.items }
        shown.move(fromOffsets: IndexSet(integer: from), toOffset: min(max(0, index), shown.count))
        return shown
    }

    /// "example.com" -> "https://example.com". nil when the text is not a usable link.
    static func normalizedLink(_ text: String) -> URL? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !t.contains(" ") else { return nil }
        if t.contains("://") {
            guard let url = URL(string: t), let scheme = url.scheme?.lowercased() else { return nil }
            if ["http", "https"].contains(scheme) { return url.host() == nil ? nil : url }
            return url
        }
        let schemeOnly = ["mailto:", "tel:", "sms:", "facetime:", "maps:", "x-apple.systempreferences:"]
        if schemeOnly.contains(where: { t.lowercased().hasPrefix($0) }) { return URL(string: t) }
        guard t.contains(".") || t.hasPrefix("localhost"),
              let url = URL(string: "https://" + t), url.host() != nil else { return nil }
        return url
    }

    /// Links found in free text (Services menu, pasteboard).
    static func links(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        var seen = Set<URL>()
        return detector.matches(in: text, range: range).compactMap(\.url).filter { seen.insert($0).inserted }
    }
}

extension LibraryStore {
    // MARK: Groups

    /// New group, auto-selected by the caller. Regular groups get their own Dock slot like `addGroup`;
    /// smart groups are computed and never get one.
    @discardableResult
    func addGroup(name: String, emoji: String?, smart: SmartGroupKind? = nil) -> ItemGroup {
        var group = ItemGroup(name: name)
        group.emoji = emoji
        group.smart = smart
        group.style = library.settings.defaultStyle
        mutate { lib in
            lib.groups.append(group)
            if smart == nil { lib.slots.append(DockSlot(name: name, groupIDs: [group.id])) }
        }
        return group
    }

    /// Next free "New Group", "New Group 2", ...
    func uniqueGroupName(_ base: String) -> String {
        let names = Set(library.groups.map(\.name))
        if !names.contains(base) { return base }
        var n = 2
        while names.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    /// Deletes a group, the Dock slots that showed only this group, and their launchers.
    func deleteGroupAndLaunchers(_ id: UUID) {
        let orphanSlots = library.slots.filter { $0.groupIDs == [id] }.map(\.id)
        mutate { lib in
            lib.groups.removeAll { $0.id == id }
            lib.slots.removeAll { orphanSlots.contains($0.id) }
            for i in lib.slots.indices { lib.slots[i].groupIDs.removeAll { $0 == id } }
        }
        for slot in orphanSlots {
            if DockManager.shared.isInDock(slotID: slot) { DockManager.shared.removeFromDock(slotID: slot) }
            DockManager.shared.removeLauncher(for: slot)
        }
    }

    func moveGroups(from source: IndexSet, to destination: Int) {
        let order = GroupOrdering.move(library, from: source, to: destination)
        mutate { $0.groups = order }
    }

    func renameGroup(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutate { lib in
            guard let i = lib.groups.firstIndex(where: { $0.id == id }) else { return }
            let old = lib.groups[i].name
            lib.groups[i].name = trimmed
            // Slots named after the group follow the rename.
            for s in lib.slots.indices where lib.slots[s].groupIDs == [id] && lib.slots[s].name == old {
                lib.slots[s].name = trimmed
            }
        }
    }

    // MARK: Items

    /// Custom name for an item. Empty text clears it and restores the original name.
    func renameItem(_ itemID: UUID, in groupID: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updateGroup(groupID) { g in
            guard let i = g.items.firstIndex(where: { $0.id == itemID }) else { return }
            g.items[i].customName = trimmed.isEmpty ? nil : trimmed
        }
    }

    /// Moves an item to another group. If the target already has it, it is only removed from the source.
    func moveItem(_ itemID: UUID, from source: UUID, to target: UUID, at index: Int? = nil) {
        guard source != target else { return }
        mutate { lib in
            guard let s = lib.groups.firstIndex(where: { $0.id == source }),
                  let t = lib.groups.firstIndex(where: { $0.id == target }),
                  lib.groups[t].smart == nil,
                  let i = lib.groups[s].items.firstIndex(where: { $0.id == itemID }) else { return }
            let item = lib.groups[s].items.remove(at: i)
            if lib.groups[t].indexOfMatch(item) == nil {
                let at = min(index ?? lib.groups[t].items.count, lib.groups[t].items.count)
                lib.groups[t].items.insert(item, at: at)
            }
        }
    }

    /// Drag inside one group: the shown order becomes manual.
    func reorderItem(_ itemID: UUID, in groupID: UUID, to index: Int) {
        updateGroup(groupID) { g in
            g.items = GroupOrdering.reorder(g, itemID: itemID, to: index)
            g.sortOrder = .manual
        }
    }

    /// Adds files, folders, apps or links at a position of the shown list. Skips duplicates.
    func insertURLs(_ urls: [URL], into groupID: UUID, at index: Int? = nil) {
        updateGroup(groupID) { g in
            var new: [DockItem] = []
            for url in urls {
                let item = DockItem(url: url)
                if g.indexOfMatch(item) == nil && !new.contains(where: { $0.url == url }) { new.append(item) }
            }
            guard !new.isEmpty else { return }
            if g.sortOrder != .manual || index == nil {
                g.items.append(contentsOf: new)
            } else {
                g.items.insert(contentsOf: new, at: min(index ?? g.items.count, g.items.count))
            }
        }
    }

    func addLink(_ url: URL, name: String?, to groupID: UUID) {
        updateGroup(groupID) { g in
            guard !g.items.contains(where: { $0.url == url }) else { return }
            var item = DockItem(kind: .link, url: url)
            if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { item.customName = name }
            g.items.append(item)
        }
    }

    /// App drawer click: adds the app, or removes it when the group already has it.
    func toggleApp(url: URL, bundleID: String?, in groupID: UUID) {
        updateGroup(groupID) { g in
            if let i = g.indexOfApp(url: url, bundleID: bundleID) {
                g.items.remove(at: i)
            } else {
                var item = DockItem(kind: .app, url: url)
                if item.bundleID == nil { item.bundleID = bundleID }
                g.items.append(item)
            }
        }
    }

    func removeItems(_ ids: Set<UUID>, from groupID: UUID) {
        updateGroup(groupID) { $0.items.removeAll { ids.contains($0.id) } }
    }
}

/// Small color dot for a group, derived from its look.
enum GroupColor {
    static func swatch(for group: ItemGroup) -> RGBA {
        let style = group.usesDefaultStyle ? LibraryStore.shared.settings.defaultStyle : group.style
        switch style.background {
        case .solid(let c): return c
        case .gradient(let colors, _), .mesh(let colors): return colors.first ?? .black
        case .glass(let tint, _): return RGBA(tint.r, tint.g, tint.b, 1)
        case .fx(let p): return p.palette.first ?? .black
        case .texture(_, let tint): return tint
        case .image, .wallpaper: return RGBA(0.5, 0.5, 0.55)
        }
    }

    static func image(for group: ItemGroup, diameter: CGFloat = 10) -> NSImage {
        let color = swatch(for: group).nsColor.withAlphaComponent(1)
        let img = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            NSColor.labelColor.withAlphaComponent(0.25).setStroke()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).stroke()
            return true
        }
        img.accessibilityDescription = group.name
        return img
    }
}
