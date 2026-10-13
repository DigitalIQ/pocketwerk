import Foundation

/// Store helpers the popup needs. All changes go through `mutate`/`updateGroup`.
extension LibraryStore {
    /// The look a popup uses for a group: global defaults or the group's own style.
    func popupStyle(of group: ItemGroup) -> GroupStyle {
        group.usesDefaultStyle ? library.settings.defaultStyle : group.style
    }

    func renameItem(_ itemID: UUID, in groupID: UUID, to name: String) {
        let owner = owningGroupID(of: itemID, fallback: groupID)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updateGroup(owner) { g in
            guard let i = g.items.firstIndex(where: { $0.id == itemID }) else { return }
            g.items[i].customName = trimmed.isEmpty ? nil : trimmed
        }
    }

    /// Moves an item into another group (appended at the end).
    func moveItem(_ itemID: UUID, from groupID: UUID, to targetID: UUID) {
        let owner = owningGroupID(of: itemID, fallback: groupID)
        guard owner != targetID else { return }
        mutate { lib in
            guard let si = lib.groups.firstIndex(where: { $0.id == owner }),
                  let ti = lib.groups.firstIndex(where: { $0.id == targetID }),
                  lib.groups[ti].smart == nil,
                  let ii = lib.groups[si].items.firstIndex(where: { $0.id == itemID }) else { return }
            let item = lib.groups[si].items.remove(at: ii)
            if !lib.groups[ti].items.contains(where: { $0.url == item.url }) {
                lib.groups[ti].items.append(item)
            }
        }
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
