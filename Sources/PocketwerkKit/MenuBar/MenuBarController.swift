import AppKit

/// Menu bar item ("Menu Bar Mode"). A click opens the carousel or a quick menu (Settings > Popup);
/// a right-click or ⌃-click always shows the menu. The menu lists groups with their items,
/// Dock profiles, settings and quit.
final class MenuBarController: NSObject, NSMenuDelegate {
    static let shared = MenuBarController()
    private var item: NSStatusItem?
    private var observer: NSObjectProtocol?
    private let menu = NSMenu()
    private var shownStyle: String?

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
                button.target = self
                button.action = #selector(clicked(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                button.setAccessibilityLabel("Pocketwerk")
            }
            item = i
            shownStyle = nil
        } else if !wanted, let i = item {
            NSStatusBar.system.removeStatusItem(i)
            item = nil
        }
        // Icon follows the style setting live; the color style also follows the group colors.
        let lib = LibraryStore.shared.library
        let style = lib.settings.menuBarIconStyle
        let key = style == MenuBarIcon.color.rawValue
            ? style + lib.carouselGroups.prefix(4).map { GroupColor.swatch(for: $0).hex }.joined() : style
        if let button = item?.button, key != shownStyle {
            button.image = MenuBarIcon(rawValue: style).map { $0.image(groups: lib.carouselGroups) }
                ?? MenuBarIcon.monochrome.image(groups: [])
            shownStyle = key
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
            PopupController.shared.toggle(groupIDs: ids, slotID: nil, anchor: anchor, source: .menuBar)
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
            PopupController.shared.toggleAll(source: .menuBar)
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
        out.append(MenuAction.item(String(localized: "Open Pocketwerk")) { MainWindowController.shared.show() })
        out.append(MenuAction.item(String(localized: "New Group…")) { MainWindowController.shared.newGroup() })
        out.append(MenuAction.item(String(localized: "Settings…"), key: ",") { MainWindowController.shared.show(page: .general) })
        let help = NSMenuItem(title: String(localized: "Help"), action: nil, keyEquivalent: "")
        let helpMenu = NSMenu()
        helpMenu.addItem(MenuAction.item(String(localized: "Pocketwerk Help")) { HelpWindowController.shared.show() })
        helpMenu.addItem(MenuAction.item(String(localized: "Report a Problem…")) { HelpWindowController.reportProblem() })
        help.submenu = helpMenu
        out.append(help)
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
            PopupController.shared.toggle(groupIDs: [group.id], slotID: nil, source: .menuBar)
        })
        sub.addItem(MenuAction.item(String(localized: "Edit Group…")) { MainWindowController.shared.show(selecting: group.id) })
        entry.submenu = sub
        return entry
    }
}

/// Looks for the menu bar icon. Template images adapt to light and dark menu bars.
enum MenuBarIcon: String, CaseIterable {
    case monochrome, filled, dots, color

    var title: String {
        switch self {
        case .monochrome: String(localized: "Outline")
        case .filled: String(localized: "Filled")
        case .dots: String(localized: "Dots")
        case .color: String(localized: "Group colors")
        }
    }

    func image(groups: [ItemGroup]) -> NSImage {
        switch self {
        case .monochrome: return symbol("square.grid.2x2")
        case .filled: return symbol("square.grid.2x2.fill")
        case .dots: return symbol("circle.grid.2x2.fill")
        case .color:
            let colors = groups.prefix(4).map { GroupColor.swatch(for: $0).nsColor.withAlphaComponent(1) }
            let fill = colors.isEmpty ? [NSColor.systemBlue, .systemPink, .systemOrange, .systemGreen] : colors
            let img = NSImage(size: NSSize(width: 16, height: 16), flipped: true) { _ in
                for i in 0..<4 {
                    let rect = NSRect(x: CGFloat(i % 2) * 8.5 + 0.5, y: CGFloat(i / 2) * 8.5 + 0.5, width: 6.5, height: 6.5)
                    fill[i % fill.count].setFill()
                    NSBezierPath(roundedRect: rect, xRadius: 1.8, yRadius: 1.8).fill()
                }
                return true
            }
            img.isTemplate = false
            img.accessibilityDescription = "Pocketwerk"
            return img
        }
    }

    private func symbol(_ name: String) -> NSImage {
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Pocketwerk") ?? NSImage()
        img.isTemplate = true
        return img
    }
}
