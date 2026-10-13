import AppKit

/// Menu bar item ("Menu Bar Mode"). A click opens the carousel or a quick menu (Settings > Popup);
/// a right-click or ⌃-click always shows the menu. The menu lists groups with their items,
/// Dock profiles, settings and quit.
final class MenuBarController: NSObject, NSMenuDelegate {
    static let shared = MenuBarController()
    private var item: NSStatusItem?
    private var observer: NSObjectProtocol?
    private let menu = NSMenu()

    func install() {
        menu.delegate = self
        menu.autoenablesItems = false
        update()
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: .libraryDidChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { MenuBarController.shared.update() }
        }
    }

    /// Shows or hides the item to match the app presence setting.
    private func update() {
        let wanted = LibraryStore.shared.settings.showMenuBarIcon
        if wanted, item == nil {
            let i = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let button = i.button {
                let image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Pocketwerk")
                image?.isTemplate = true
                button.image = image
                button.target = self
                button.action = #selector(clicked(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                button.setAccessibilityLabel("Pocketwerk")
            }
            item = i
        } else if !wanted, let i = item {
            NSStatusBar.system.removeStatusItem(i)
            item = nil
        }
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
            || LibraryStore.shared.settings.menuBarClick == .menu
        if wantsMenu {
            showMenu()
        } else {
            let anchor = sender.window.map { w in
                let frame = w.convertToScreen(sender.convert(sender.bounds, to: nil))
                return CGPoint(x: frame.midX, y: frame.minY)
            }
            let ids = LibraryStore.shared.library.carouselGroups.map(\.id)
            PopupController.shared.toggle(groupIDs: ids, slotID: nil, anchor: anchor)
        }
    }

    private func showMenu() {
        guard let item else { return }
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for entry in Self.buildItems() { menu.addItem(entry) }
    }

    /// The whole menu, rebuilt on every open so it is always current.
    static func buildItems() -> [NSMenuItem] {
        let store = LibraryStore.shared
        let lib = store.library
        var out: [NSMenuItem] = []

        if let release = UpdateChecker.shared.available {
            out.append(MenuAction.item(String(localized: "Update Available: \(release.version)…")) {
                MainWindowController.shared.show(page: .updates)
            })
            out.append(.separator())
        }

        let all = MenuAction.item(String(localized: "Show All Groups")) {
            PopupController.shared.toggle(groupIDs: lib.carouselGroups.map(\.id), slotID: nil)
        }
        all.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
        out.append(all)
        out.append(.separator())

        let header = NSMenuItem(title: String(localized: "Groups"), action: nil, keyEquivalent: "")
        header.isEnabled = false
        out.append(header)
        for group in lib.carouselGroups { out.append(groupItem(group)) }
        if lib.carouselGroups.isEmpty {
            let none = NSMenuItem(title: String(localized: "No Groups"), action: nil, keyEquivalent: "")
            none.isEnabled = false
            out.append(none)
        }

        if !lib.profiles.isEmpty {
            out.append(.separator())
            let profiles = NSMenuItem(title: String(localized: "Dock Profiles"), action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for p in lib.profiles {
                let entry = MenuAction.item(p.name) { DockProfiles.shared.apply(p.id) }
                if p.id == lib.settings.lastAppliedProfileID { entry.state = .on }
                sub.addItem(entry)
            }
            profiles.submenu = sub
            profiles.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: nil)
            out.append(profiles)
        }

        out.append(.separator())
        out.append(MenuAction.item(String(localized: "New Group…")) { MainWindowController.shared.newGroup() })
        out.append(MenuAction.item(String(localized: "Settings…"), key: ",") { MainWindowController.shared.show(page: .general) })
        out.append(.separator())
        out.append(NSMenuItem(title: String(localized: "Quit Pocketwerk"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return out
    }

    /// A group with a color swatch; its submenu lists the items, Open All and Show.
    private static func groupItem(_ group: ItemGroup) -> NSMenuItem {
        let store = LibraryStore.shared
        let title = [group.emoji, group.name].compactMap { $0 }.joined(separator: " ")
        let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        entry.image = GroupColor.image(for: group)
        let sub = NSMenu()
        let items = store.visibleItems(of: group)
        for item in items {
            let owner = store.owningGroupID(of: item.id, fallback: group.id)
            let row = MenuAction.item(item.displayName) { ItemOpener.open(item, in: owner) }
            row.image = IconRenderer.icon(for: item, size: 16)
            if !item.exists { row.isEnabled = false }
            sub.addItem(row)
        }
        if items.isEmpty {
            let none = NSMenuItem(title: String(localized: "Empty"), action: nil, keyEquivalent: "")
            none.isEnabled = false
            sub.addItem(none)
        }
        sub.addItem(.separator())
        let openAll = MenuAction.item(String(localized: "Open All")) { OpenAllAction.run(group) }
        openAll.isEnabled = items.count > 0
        sub.addItem(openAll)
        sub.addItem(MenuAction.item(String(localized: "Show Group")) {
            PopupController.shared.toggle(groupIDs: [group.id], slotID: nil)
        })
        sub.addItem(MenuAction.item(String(localized: "Edit Group…")) { MainWindowController.shared.show(selecting: group.id) })
        entry.submenu = sub
        return entry
    }
}
