import AppKit

/// Standard app menu so Cmd-Q, Cmd-W, copy/paste and Cmd-Z work in windows.
enum MainMenu {
    static func install() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: String(localized: "About Pocketwerk"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(MenuAction.item(String(localized: "Settings…"), key: ",") { MainWindowController.shared.show(page: .general) })
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Hide Pocketwerk"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: String(localized: "Quit Pocketwerk"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let fileItem = NSMenuItem()
        let file = NSMenu(title: String(localized: "File"))
        file.addItem(MenuAction.item(String(localized: "New Group"), key: "n") { MainWindowController.shared.newGroup() })
        let smart = NSMenuItem(title: String(localized: "New Smart Group"), action: nil, keyEquivalent: "")
        let smartMenu = NSMenu()
        for kind in SmartGroupKind.allCases {
            smartMenu.addItem(MenuAction.item(SmartGroups.title(kind)) { MainWindowController.shared.newGroup(smart: kind) })
        }
        smart.submenu = smartMenu
        file.addItem(smart)
        file.addItem(.separator())
        file.addItem(MenuAction.item(String(localized: "Add Apps…"), key: "a") { MainWindowController.shared.showAppDrawer() }
            .with(modifiers: [.command, .shift]))
        file.addItem(MenuAction.item(String(localized: "Add Files…"), key: "f") { MainWindowController.shared.addFiles() }
            .with(modifiers: [.command, .shift]))
        file.addItem(MenuAction.item(String(localized: "Add Link…"), key: "l") { MainWindowController.shared.addLink() }
            .with(modifiers: [.command, .shift]))
        file.addItem(.separator())
        file.addItem(MenuAction.item(String(localized: "Show All Groups")) {
            PopupController.shared.toggleAll(source: .hotkey)
        })
        file.addItem(.separator())
        file.addItem(withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = file
        main.addItem(fileItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: String(localized: "Edit"))
        edit.addItem(MenuAction.item(String(localized: "Undo"), key: "z") {
            if let text = activeTextUndo(), text.canUndo { text.undo() } else { LibraryStore.shared.undo() }
        })
        let redo = MenuAction.item(String(localized: "Redo"), key: "z") {
            if let text = activeTextUndo(), text.canRedo { text.redo() } else { LibraryStore.shared.redo() }
        }
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        edit.addItem(withTitle: String(localized: "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let viewItem = NSMenuItem()
        let view = NSMenu(title: String(localized: "View"))
        view.addItem(MenuAction.item(String(localized: "Toggle Sidebar"), key: "s") { MainWindowController.shared.toggleSidebar() }
            .with(modifiers: [.command, .control]))
        viewItem.submenu = view
        main.addItem(viewItem)

        let windowItem = NSMenuItem()
        let window = NSMenu(title: String(localized: "Window"))
        window.addItem(MenuAction.item(String(localized: "Pocketwerk"), key: "0") { MainWindowController.shared.show() })
        window.addItem(.separator())
        window.addItem(withTitle: String(localized: "Minimize"), action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = window
        main.addItem(windowItem)
        NSApp.windowsMenu = window

        NSApp.mainMenu = main
    }

    /// While a text field is being edited, ⌘Z belongs to its text, not to the library.
    private static func activeTextUndo() -> UndoManager? {
        guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.isFieldEditor || editor.isEditable else {
            return nil
        }
        return editor.undoManager
    }
}

extension NSMenuItem {
    /// Sets the key equivalent modifiers inline.
    func with(modifiers: NSEvent.ModifierFlags) -> NSMenuItem {
        keyEquivalentModifierMask = modifiers
        return self
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
