import AppKit

/// Right-click menu of the main app's Dock tile.
enum DockMenus {
    /// Each group as a submenu (its items, then Open All, Hide All, Quit All), then the Dock profiles.
    /// AppCoordinator returns this from `applicationDockMenu(_:)`.
    static func mainMenu(store: LibraryStore = .shared) -> NSMenu {
        let menu = NSMenu()
        for group in store.library.groups {
            let sub = NSMenu()
            add(items: store.visibleItems(of: group), groupID: group.id, to: sub)
            let item = NSMenuItem(title: group.name, action: nil, keyEquivalent: "")
            item.submenu = sub
            menu.addItem(item)
        }
        let profiles = store.library.profiles
        if !profiles.isEmpty {
            if menu.numberOfItems > 0 { menu.addItem(.separator()) }
            let sub = NSMenu()
            for p in profiles {
                let item = MenuAction.item(p.name) { DockProfiles.shared.apply(p.id) }
                item.state = store.settings.lastAppliedProfileID == p.id ? .on : .off
                sub.addItem(item)
            }
            if store.settings.lastAppliedProfileID != nil {
                sub.addItem(.separator())
                sub.addItem(MenuAction.item(String(localized: "Save Current Dock to Active Profile")) {
                    DockProfiles.shared.saveCurrentToActive()
                })
            }
            let item = NSMenuItem(title: String(localized: "Dock Profiles"), action: nil, keyEquivalent: "")
            item.submenu = sub
            menu.addItem(item)
        }
        return menu
    }

    /// Item list plus the three bulk actions, as used by the group submenus.
    static func add(items: [DockItem], groupID: UUID, to menu: NSMenu) {
        for entry in items {
            let icon = IconRenderer.icon(for: entry, size: 16)
            menu.addItem(MenuAction.item(entry.displayName, image: icon) {
                ItemOpener.open(entry, in: LibraryStore.shared.owningGroupID(of: entry.id, fallback: groupID))
            })
        }
        guard !items.isEmpty else { return }
        menu.addItem(.separator())
        menu.addItem(MenuAction.item(String(localized: "Open All")) {
            for (i, entry) in items.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + LibraryStore.shared.settings.openAllDelay * Double(i)) {
                    ItemOpener.open(entry, in: groupID)
                }
            }
        })
        let ids = Set(items.filter { $0.kind == .app }.compactMap { $0.bundleID ?? Bundle(url: $0.url)?.bundleIdentifier })
        guard !ids.isEmpty else { return }
        let running = { NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier.map(ids.contains) ?? false } }
        menu.addItem(MenuAction.item(String(localized: "Hide All")) { running().forEach { $0.hide() } })
        menu.addItem(MenuAction.item(String(localized: "Quit All")) { running().forEach { $0.terminate() } })
    }
}
