import AppKit

/// Asks which group dropped items go to, when the drop target does not say it
/// (a smart group, a folder view, or the main Dock icon).
enum PopupGroupPicker {
    /// Menu at the pointer: one entry per group that stores items. With one group there is nothing to ask.
    static func present(for urls: [URL], model: PopupModel? = nil, at point: NSPoint? = nil) {
        let store = LibraryStore.shared
        let targets = store.library.regularGroups
        guard !urls.isEmpty, !targets.isEmpty else { NSSound.beep(); return }
        if targets.count == 1 {
            store.insertURLs(urls, into: targets[0].id)
            return
        }
        let menu = NSMenu()
        let title = urls.count == 1
            ? String(localized: "Add “\(DockItem(url: urls[0]).displayName)” to")
            : String(localized: "Add \(urls.count) Items to")
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for group in targets {
            let item = MenuAction.item(group.name, image: GroupColor.image(for: group)) {
                store.insertURLs(urls, into: group.id)
                if let model, let i = model.groupIDs.firstIndex(of: group.id) { model.showGroup(at: i) }
            }
            if let emoji = group.emoji, !emoji.isEmpty { item.title = "\(emoji)  \(group.name)" ; item.image = nil }
            menu.addItem(item)
        }
        model?.actions.suspendAutoClose(true)
        menu.popUp(positioning: nil, at: point ?? NSEvent.mouseLocation, in: nil)
        model?.actions.suspendAutoClose(false)
    }
}
