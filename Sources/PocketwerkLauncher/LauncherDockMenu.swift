import AppKit
import PocketwerkShared

/// One entry of the slot, read from the main app's library file.
struct LauncherItem {
    var name: String
    var url: URL
    var isApp: Bool
    var bundleID: String?

    /// Apps are found by bundle ID first, so the entry survives when the app moves.
    var resolvedURL: URL {
        if isApp, let bundleID, let found = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return found
        }
        return url
    }
}

struct LauncherGroup {
    var name: String
    var items: [LauncherItem]
}

/// Reads the slot's groups from library.json. Read-only; the launcher never writes it.
enum LauncherLibrary {
    static func groups(slotID: String, libraryURL: URL = PWShared.libraryURL()) -> [LauncherGroup] {
        guard let data = try? Data(contentsOf: libraryURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return groups(slotID: slotID, root: root)
    }

    static func groups(slotID: String, root: [String: Any]) -> [LauncherGroup] {
        let slots = root["slots"] as? [[String: Any]] ?? []
        guard let slot = slots.first(where: { ($0["id"] as? String)?.caseInsensitiveCompare(slotID) == .orderedSame }) else { return [] }
        let groupIDs = (slot["groupIDs"] as? [String] ?? []).map { $0.uppercased() }
        let groups = root["groups"] as? [[String: Any]] ?? []
        return groupIDs.compactMap { gid in
            guard let g = groups.first(where: { ($0["id"] as? String)?.uppercased() == gid }) else { return nil }
            let items = (g["items"] as? [[String: Any]] ?? []).compactMap(item)
            return LauncherGroup(name: g["name"] as? String ?? "", items: items)
        }
    }

    static func item(_ dict: [String: Any]) -> LauncherItem? {
        let raw: String?
        if let s = dict["url"] as? String { raw = s } else { raw = (dict["url"] as? [String: Any])?["relative"] as? String }
        guard let raw, let url = URL(string: raw) else { return nil }
        let kind = dict["kind"] as? String ?? "file"
        var name = dict["customName"] as? String ?? ""
        if name.isEmpty {
            if url.isFileURL {
                name = FileManager.default.displayName(atPath: url.path)
                if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
            } else {
                name = url.host(percentEncoded: false) ?? url.absoluteString
            }
        }
        return LauncherItem(name: name, url: url, isApp: kind == "app", bundleID: dict["bundleID"] as? String)
    }
}

/// Right-click menu of the tile: every item, then Open All, Hide All, Quit All.
final class LauncherDockMenu: NSObject {
    let slotID: String
    private var items: [LauncherItem] = []

    init(slotID: String) { self.slotID = slotID }

    func menu() -> NSMenu {
        let groups = LauncherLibrary.groups(slotID: slotID)
        items = groups.flatMap(\.items)
        let menu = NSMenu()
        var index = 0
        for group in groups {
            if groups.count > 1 {
                if menu.numberOfItems > 0 { menu.addItem(.separator()) }
                let header = NSMenuItem(title: group.name, action: nil, keyEquivalent: "")
                header.isEnabled = false
                menu.addItem(header)
            }
            for item in group.items {
                let mi = NSMenuItem(title: item.name, action: #selector(openItem(_:)), keyEquivalent: "")
                mi.target = self
                mi.tag = index
                let icon = NSWorkspace.shared.icon(forFile: item.resolvedURL.path)
                icon.size = NSSize(width: 16, height: 16)
                mi.image = item.url.isFileURL ? icon : NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
                menu.addItem(mi)
                index += 1
            }
        }
        guard !items.isEmpty else { return menu }
        menu.addItem(.separator())
        add(menu, String(localized: "Open All"), #selector(openAll))
        if items.contains(where: \.isApp) {
            add(menu, String(localized: "Hide All"), #selector(hideAll))
            add(menu, String(localized: "Quit All"), #selector(quitAll))
        }
        return menu
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: Selector) {
        let mi = NSMenuItem(title: title, action: action, keyEquivalent: "")
        mi.target = self
        menu.addItem(mi)
    }

    @objc private func openItem(_ sender: NSMenuItem) {
        guard items.indices.contains(sender.tag) else { return }
        open(items[sender.tag], activate: true)
    }

    @objc private func openAll() {
        for (i, item) in items.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 * Double(i)) { [self] in
                open(item, activate: i == items.count - 1)
            }
        }
    }

    @objc private func hideAll() {
        for app in runningApps() { app.hide() }
    }

    @objc private func quitAll() {
        for app in runningApps() { app.terminate() }
    }

    private func runningApps() -> [NSRunningApplication] {
        let ids = Set(items.filter(\.isApp).compactMap { $0.bundleID ?? Bundle(url: $0.url)?.bundleIdentifier })
        return NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier.map(ids.contains) ?? false }
    }

    private func open(_ item: LauncherItem, activate: Bool) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = activate
        if item.isApp {
            NSWorkspace.shared.openApplication(at: item.resolvedURL, configuration: config)
        } else {
            NSWorkspace.shared.open(item.url, configuration: config)
        }
    }
}
