import AppKit

// OWNER: popup agent. Placeholder with the final API.

enum ItemOpener {
    /// Opens an app, file, folder or link and records usage.
    static func open(_ item: DockItem, in groupID: UUID) {
        if item.kind == .app {
            NSWorkspace.shared.openApplication(at: item.url, configuration: .init())
        } else {
            NSWorkspace.shared.open(item.url)
        }
        LibraryStore.shared.recordOpen(item.id, in: groupID)
    }

    /// Opens every item of a group.
    static func openAll(_ group: ItemGroup) {
        for item in group.sortedItems { open(item, in: group.id) }
    }
}
