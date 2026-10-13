import Foundation

/// Store helpers the popup needs. All changes go through `mutate`/`updateGroup`.
extension LibraryStore {
    /// The look a popup uses for a group: global defaults or the group's own style.
    func popupStyle(of group: ItemGroup) -> GroupStyle {
        var style = group.usesDefaultStyle ? library.settings.defaultStyle : group.style
        // "Popup follows Dock icon": fill, opacity and finish come from the group's icon.
        if style.mirrorIcon, let fill = group.icon.background {
            style.background = fill
            style.opacity = group.icon.opacity
            style.matte = group.icon.matte
            if let border = group.icon.border { style.border = border }
        }
        return style
    }

    /// Points a missing item at its new location. Apps also take the new bundle ID.
    func relinkItem(_ itemID: UUID, in groupID: UUID, to url: URL) {
        updateGroup(owningGroupID(of: itemID, fallback: groupID)) { g in
            guard let i = g.items.firstIndex(where: { $0.id == itemID }) else { return }
            g.items[i].url = url
            if g.items[i].kind == .app, let id = Bundle(url: url)?.bundleIdentifier { g.items[i].bundleID = id }
        }
        LibraryHealth.shared.scheduleScan()
    }

    /// Adds URLs at a position of the shown (possibly sorted) order. Existing URLs are skipped.
    func insertItems(_ urls: [URL], into groupID: UUID, atShownIndex index: Int, shown: [DockItem]) {
        guard let group = group(groupID), group.smart == nil else { return }
        if group.sortOrder == .manual {
            addItems(urls, to: groupID, at: index)
            return
        }
        // Sorted groups: keep what the user sees and switch to manual order.
        updateGroup(groupID) { g in
            let existing = Set(g.items.map(\.url))
            let new = urls.filter { !existing.contains($0) }.map { DockItem(url: $0) }
            var ordered = shown.compactMap { s in g.items.first { $0.id == s.id } }
            ordered += g.items.filter { i in !ordered.contains { $0.id == i.id } }
            ordered.insert(contentsOf: new, at: min(max(index, 0), ordered.count))
            g.items = ordered
            g.sortOrder = .manual
        }
    }

    /// Moves an item to a position of the shown order; the group becomes manually sorted.
    func reorderItem(_ itemID: UUID, in groupID: UUID, toShownIndex index: Int, shown: [DockItem]) {
        guard let group = group(groupID), group.smart == nil else { return }
        let order = ReorderMath.move(itemID, to: index, shown: shown.map(\.id))
        updateGroup(groupID) { g in
            var ordered = order.compactMap { id in g.items.first { $0.id == id } }
            ordered += g.items.filter { i in !order.contains(i.id) }
            g.items = ordered
            g.sortOrder = .manual
        }
    }

    /// Live zoom (⌘+ / ⌘-): changes the icon size of the style the group really uses. Not undoable.
    func adjustIconSize(of groupID: UUID, by delta: Double) {
        guard let group = group(groupID) else { return }
        if group.usesDefaultStyle {
            mutate(undoable: false) { $0.settings.defaultStyle.iconSize = min(max($0.settings.defaultStyle.iconSize + delta, 24), 128) }
        } else {
            updateGroup(groupID, undoable: false) { $0.style.iconSize = min(max($0.style.iconSize + delta, 24), 128) }
        }
    }
}
