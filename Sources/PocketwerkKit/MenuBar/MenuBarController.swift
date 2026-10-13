import AppKit

// OWNER: app agent. Placeholder with the final API.

/// Menu bar item ("Menu Bar Mode"): opens groups, Dock profiles, settings.
final class MenuBarController {
    static let shared = MenuBarController()
    private var item: NSStatusItem?

    func install() {
        guard LibraryStore.shared.settings.showMenuBarIcon, item == nil else { return }
        let i = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        i.button?.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Pocketwerk")
        let menu = NSMenu()
        menu.addItem(MenuAction.item("Alle Gruppen") { PopupController.shared.toggleAll() })
        menu.addItem(MenuAction.item("Einstellungen …") { MainWindowController.shared.show() })
        menu.addItem(.separator())
        menu.addItem(withTitle: "Beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        i.menu = menu
        item = i
    }
}
