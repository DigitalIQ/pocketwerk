import AppKit

/// Standard app menu so Cmd-Q, Cmd-W, copy/paste and Cmd-Z work in windows.
enum MainMenu {
    static func install() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: String(localized: "About Pocketwerk"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(MenuAction.item(String(localized: "Settings…"), key: ",") { MainWindowController.shared.show() })
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Hide Pocketwerk"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: String(localized: "Quit Pocketwerk"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: String(localized: "Edit"))
        edit.addItem(MenuAction.item(String(localized: "Undo"), key: "z") { LibraryStore.shared.undo() })
        let redo = MenuAction.item(String(localized: "Redo"), key: "z") { LibraryStore.shared.redo() }
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        edit.addItem(withTitle: String(localized: "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let window = NSMenu(title: String(localized: "Window"))
        window.addItem(withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(withTitle: String(localized: "Minimize"), action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = window
        main.addItem(windowItem)
        NSApp.windowsMenu = window

        NSApp.mainMenu = main
    }
}

/// NSMenuItem with a closure. Keeps the target alive via representedObject.
final class MenuAction: NSObject {
    let handler: () -> Void
    init(_ handler: @escaping () -> Void) { self.handler = handler }
    @objc func fire(_ sender: Any?) { handler() }

    static func item(_ title: String, key: String = "", image: NSImage? = nil, _ handler: @escaping () -> Void) -> NSMenuItem {
        let action = MenuAction(handler)
        let item = NSMenuItem(title: title, action: #selector(MenuAction.fire(_:)), keyEquivalent: key)
        item.target = action
        item.representedObject = action
        item.image = image
        return item
    }
}
