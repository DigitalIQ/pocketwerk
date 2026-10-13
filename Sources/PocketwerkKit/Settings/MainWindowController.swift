import AppKit
import Observation
import SwiftUI

/// Pages in the Settings part of the sidebar.
enum SettingsPage: String, CaseIterable, Hashable, Identifiable {
    case general, popup, hotkeys, backup, diagnostics, updates, about
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .popup: "Popup"
        case .hotkeys: "Hotkeys"
        case .backup: "Backup"
        case .diagnostics: "Diagnostics"
        case .updates: "Updates"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .popup: "rectangle.on.rectangle"
        case .hotkeys: "keyboard"
        case .backup: "externaldrive"
        case .diagnostics: "stethoscope"
        case .updates: "arrow.down.circle"
        case .about: "info.circle"
        }
    }
}

enum SidebarItem: Hashable {
    case group(UUID)
    case dockIcons
    case profiles
    case settings(SettingsPage)
}

enum GroupTab: String, CaseIterable, Hashable {
    case items, appearance, options, assistant
}

/// UI state of the main window, shared by the menu commands.
@Observable
final class MainWindowModel {
    var selection: SidebarItem?
    var renamingGroupID: UUID?
    var groupTab: GroupTab = .items
    var showAppDrawer = false
    var showAddLink = false
    var deleteCandidate: UUID?
    var showGroupSuggestions = false
    var columnVisibility: NavigationSplitViewVisibility = .all

    var selectedGroupID: UUID? {
        if case .group(let id) = selection { return id }
        return nil
    }
}

/// The management window: groups, items, Dock icons, profiles, settings.
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()
    let model = MainWindowModel()
    private var window: NSWindow?

    func show(selecting groupID: UUID? = nil) {
        if let groupID {
            model.selection = .group(groupID)
        } else if model.selection == nil {
            model.selection = LibraryStore.shared.library.orderedGroups.first.map { .group($0.id) } ?? .settings(.general)
        }
        open()
    }

    func show(page: SettingsPage) {
        model.selection = .settings(page)
        open()
    }

    private func open() {
        // First launch: the welcome comes first, the main window follows when it closes.
        if WelcomeWindowController.shared.isShowing {
            WelcomeWindowController.shared.mainWindowPending = true
            WelcomeWindowController.shared.show()
            return
        }
        if window == nil {
            model.columnVisibility = LibraryStore.shared.settings.sidebarCollapsed ? .detailOnly : .all
            // The Design Studio needs about 1000 x 640 next to the sidebar.
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1260, height: 800),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "Pocketwerk"
            w.isReleasedWhenClosed = false
            w.toolbarStyle = .unified
            w.contentMinSize = NSSize(width: 900, height: 600)
            let hosting = NSHostingController(rootView: MainWindowView(model: model))
            hosting.sizingOptions = [.minSize]
            w.contentViewController = hosting
            w.setContentSize(NSSize(width: 1260, height: 800))
            if !w.setFrameUsingName("PocketwerkMainWindow2") { w.center() }
            w.setFrameAutosaveName("PocketwerkMainWindow2")
            w.delegate = self
            window = w
        }
        LibraryHealth.shared.scheduleScan()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    var isVisible: Bool { window?.isVisible == true }

    // MARK: Commands

    /// ⌘N: new group, selected and ready to rename.
    func newGroup(smart: SmartGroupKind? = nil) {
        let store = LibraryStore.shared
        let name = smart.map(SmartGroups.title) ?? store.uniqueGroupName(String(localized: "New Group"))
        let g = store.addGroup(name: name, emoji: nil, smart: smart)
        show(selecting: g.id)
        model.groupTab = .items
        if smart == nil { model.renamingGroupID = g.id }
    }

    /// ⇧⌘F: add files or folders to the selected group.
    func addFiles() {
        guard let id = model.selectedGroupID ?? LibraryStore.shared.library.regularGroups.first?.id,
              LibraryStore.shared.group(id)?.smart == nil else {
            NSSound.beep()
            return
        }
        show(selecting: id)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: "Add")
        panel.message = String(localized: "Choose apps, files or folders to add.")
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK else { return }
            let urls = panel.urls
            MainActor.assumeIsolated { LibraryStore.shared.insertURLs(urls, into: id) }
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: completion) } else { completion(panel.runModal()) }
    }

    func addLink() {
        guard let id = model.selectedGroupID, LibraryStore.shared.group(id)?.smart == nil else { NSSound.beep(); return }
        model.groupTab = .items
        model.showAddLink = true
    }

    func showAppDrawer() {
        guard let id = model.selectedGroupID, LibraryStore.shared.group(id)?.smart == nil else { NSSound.beep(); return }
        model.groupTab = .items
        model.showAppDrawer = true
    }

    func toggleSidebar() {
        model.columnVisibility = model.columnVisibility == .detailOnly ? .all : .detailOnly
    }

    func windowWillClose(_ notification: Notification) {
        model.renamingGroupID = nil
    }
}
