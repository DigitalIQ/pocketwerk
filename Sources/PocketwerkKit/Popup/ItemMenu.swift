import AppKit
import UniformTypeIdentifiers

/// Right-click menus of the popup.
enum ItemMenu {
    /// Menu for one item. Stored items get rename, remove and move; folder contents get "Add to Group".
    static func menu(for item: DockItem, group: ItemGroup, model: PopupModel) -> NSMenu {
        let menu = NSMenu()
        let store = LibraryStore.shared
        let running = item.kind == .app ? RunningApps.shared.app(for: item) : nil
        let editable = model.isEditable(in: group)

        if editable, MissingItemActions.isMissing(item) {
            menu.addItem(MenuAction.item(String(localized: "Locate…")) { MissingItemActions.locate(item, group: group, model: model) })
            menu.addItem(.separator())
        }
        menu.addItem(MenuAction.item(running == nil ? String(localized: "Open") : String(localized: "Show")) {
            model.activate(item, in: group)
        })
        if item.kind == .folder {
            menu.addItem(MenuAction.item(String(localized: "Open in Finder")) {
                model.actions.willLaunch()
                NSWorkspace.shared.open(item.url)
                model.actions.didLaunch()
            })
        }
        if item.kind != .app {
            menu.addItem(openWithItem(for: item, model: model))
        }
        if item.kind != .link {
            menu.addItem(MenuAction.item(String(localized: "Show in Finder")) {
                model.actions.willLaunch()
                ItemOpener.revealInFinder([item])
                model.actions.didLaunch()
            })
        }
        menu.addItem(MenuAction.item(String(localized: "Quick Look")) { model.actions.quickLook(item) })

        if let running {
            menu.addItem(.separator())
            menu.addItem(MenuAction.item(running.isHidden ? String(localized: "Unhide") : String(localized: "Hide")) {
                if running.isHidden { running.unhide() } else { running.hide() }
            })
            menu.addItem(MenuAction.item(String(localized: "Quit")) { running.terminate() })
            menu.addItem(MenuAction.item(String(localized: "Force Quit")) { running.forceTerminate() })
        }

        menu.addItem(.separator())
        if editable {
            menu.addItem(MenuAction.item(String(localized: "Rename…")) { model.renaming = item.url })
            let owner = store.owningGroupID(of: item.id, fallback: group.id)
            let targets = store.library.groups.filter { $0.smart == nil && $0.id != owner }
            if !targets.isEmpty {
                let move = NSMenuItem(title: String(localized: "Move to Group"), action: nil, keyEquivalent: "")
                let sub = NSMenu()
                for target in targets {
                    sub.addItem(MenuAction.item(target.name) { store.moveItem(item.id, from: owner, to: target.id) })
                }
                move.submenu = sub
                menu.addItem(move)
            }
            menu.addItem(MenuAction.item(String(localized: "Remove from Group")) {
                store.removeItem(item.id, from: owner)
            })
        } else if model.isInFolder {
            let targets = store.library.groups.filter { $0.smart == nil }
            if !targets.isEmpty {
                let add = NSMenuItem(title: String(localized: "Add to Group"), action: nil, keyEquivalent: "")
                let sub = NSMenu()
                for target in targets {
                    sub.addItem(MenuAction.item(target.name) { store.addItems([item.url], to: target.id) })
                }
                add.submenu = sub
                menu.addItem(add)
            }
        }
        return menu
    }

    /// "Open With" submenu: apps that can open the item, default first, plus "Other…".
    private static func openWithItem(for item: DockItem, model: PopupModel) -> NSMenuItem {
        let parent = NSMenuItem(title: String(localized: "Open With"), action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let ws = NSWorkspace.shared
        let defaultApp = ws.urlForApplication(toOpen: item.url)
        var apps = ws.urlsForApplications(toOpen: item.url)
        if let d = defaultApp { apps.removeAll { $0 == d }; apps.insert(d, at: 0) }
        var seen = Set<String>()
        for app in apps.prefix(24) where seen.insert(app.path).inserted {
            var title = FileManager.default.displayName(atPath: app.path).replacingOccurrences(of: ".app", with: "")
            if app == defaultApp { title += " " + String(localized: "(default)") }
            let icon = ws.icon(forFile: app.path)
            icon.size = NSSize(width: 16, height: 16)
            sub.addItem(MenuAction.item(title, image: icon) {
                model.actions.willLaunch()
                ItemOpener.open([item.url], withApp: app)
                model.actions.didLaunch()
            })
        }
        if !apps.isEmpty { sub.addItem(.separator()) }
        sub.addItem(MenuAction.item(String(localized: "Other…")) {
            model.actions.suspendAutoClose(true)
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.application]
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
            panel.prompt = String(localized: "Open")
            NSApp.activate()
            let response = panel.runModal()
            model.actions.suspendAutoClose(false)
            if response == .OK, let app = panel.url {
                model.actions.willLaunch()
                ItemOpener.open([item.url], withApp: app)
                model.actions.didLaunch()
            }
        })
        parent.submenu = sub
        return parent
    }

    /// Menu on the popup background: whole-group actions.
    static func backgroundMenu(group: ItemGroup, model: PopupModel) -> NSMenu {
        let menu = NSMenu()
        let items = model.baseItems(of: group)
        if !items.isEmpty {
            menu.addItem(MenuAction.item(String(localized: "Open All")) {
                model.openAllArmed = true
                model.openAll(in: group)
            })
        }
        if items.contains(where: { $0.kind == .app }) {
            menu.addItem(MenuAction.item(String(localized: "Hide All")) { model.closeAll(in: group, modifiers: []) })
            menu.addItem(MenuAction.item(String(localized: "Quit All")) { model.closeAll(in: group, modifiers: .option) })
            menu.addItem(MenuAction.item(String(localized: "Force Quit All")) { model.closeAll(in: group, modifiers: .command) })
        }
        if model.isEditable(in: group) {
            menu.addItem(.separator())
            menu.addItem(MenuAction.item(String(localized: "Add Files…")) { addFiles(to: group, model: model) })
        }
        menu.addItem(.separator())
        menu.addItem(MenuAction.item(model.pinned ? String(localized: "Close Window") : String(localized: "Keep Open as Window")) {
            model.actions.togglePin()
        })
        return menu
    }

    /// File picker for apps, files and folders.
    static func addFiles(to group: ItemGroup, model: PopupModel) {
        model.actions.suspendAutoClose(true)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: "Add")
        NSApp.activate()
        let response = panel.runModal()
        model.actions.suspendAutoClose(false)
        if response == .OK { LibraryStore.shared.addItems(panel.urls, to: group.id) }
    }
}
