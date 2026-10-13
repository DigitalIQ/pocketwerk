import AppKit
import Observation

/// Contents of a folder opened inside the popup.
struct FolderLevel: Equatable {
    var url: URL
    var items: [DockItem] = []
    var loading = true

    var name: String { FileManager.default.displayName(atPath: url.path) }
}

/// What a popup shows and how it is being used. One model per popup window.
@Observable
final class PopupModel {
    var groupIDs: [UUID]
    var slotID: UUID?
    var position = CarouselPosition(group: 0, page: 0)
    /// -1 = moved back, 1 = moved forward. Picks the slide direction.
    var slideDirection = 1
    var folderStack: [FolderLevel] = []
    /// Keyboard selection, index into `shownItems`.
    var selection: Int?
    /// The focus ring shows only while the keyboard drives the selection, not after a click.
    var focusVisible = false
    /// ⌘-click multi-selection for "Open Selected".
    var picked: Set<URL> = []
    var query = ""
    var pinned = false
    var isVisible = false
    var renaming: URL?
    var hovered: URL?
    var pressed: URL?
    var openAllArmed = false
    /// Insertion index (in `shownItems`) while something is dragged over the popup.
    var dropIndex: Int?
    /// Item under a drag that would open the dropped files.
    var dropOnItem: Int?
    /// Item currently dragged out of this popup.
    var dragging: URL?
    var pointer: CGPoint?
    var modifiers: NSEvent.ModifierFlags = []
    /// Largest size the popup may take on its screen.
    var maxSize = CGSize(width: 1600, height: 1000)
    /// Size of the window. The card fills it, so locked sizes and resizes stay smooth.
    var panelSize: CGSize?

    /// Set by the controller: close, resize, Quick Look, pin.
    @ObservationIgnored var actions = PopupActions()
    @ObservationIgnored private var armTask: Task<Void, Never>?

    init(groupIDs: [UUID], slotID: UUID? = nil) {
        self.groupIDs = groupIDs
        self.slotID = slotID
    }

    /// The library this popup reads. Previews may pass their own.
    @ObservationIgnored var store: LibraryStore = .shared

    var currentGroup: ItemGroup? {
        guard !groupIDs.isEmpty else { return nil }
        let i = min(max(position.group, 0), groupIDs.count - 1)
        return store.group(groupIDs[i])
    }

    var groups: [ItemGroup] { groupIDs.compactMap { store.group($0) } }

    var isInFolder: Bool { !folderStack.isEmpty }

    /// Items of the current view before search: the group, or the opened folder.
    func baseItems(of group: ItemGroup) -> [DockItem] {
        if let folder = folderStack.last { return folder.items }
        return store.visibleItems(of: group)
    }

    /// Items as shown: after search.
    func shownItems(of group: ItemGroup) -> [DockItem] {
        let cache = PopupIconCache.shared
        return PopupSearch.filter(baseItems(of: group), query: query) { cache.name(for: $0) }
    }

    /// Number of cells, including the "Open in Finder" cell inside folders.
    func cellCount(of group: ItemGroup) -> Int {
        shownItems(of: group).count + (isInFolder ? 1 : 0)
    }

    func metrics(for group: ItemGroup) -> PopupMetrics {
        var input = layoutInput(for: group, items: shownItems(of: group), extraCells: isInFolder ? 1 : 0)
        // Folders need the back button, search shows its text, pinned windows their close button.
        if isInFolder || !query.isEmpty || pinned || !picked.isEmpty { input.showHeader = true }
        // Inside a folder or a search the carousel pauses, so its dots go away.
        if isInFolder || !query.isEmpty { input.groupCount = 1 }
        return PopupMetrics.compute(input)
    }

    /// Layout input for a group in this popup: screen room minus the sidebar, two-line labels when needed.
    func layoutInput(for group: ItemGroup, items: [DockItem], extraCells: Int = 0) -> PopupLayoutInput {
        let style = store.popupStyle(of: group)
        var room = maxSize
        room.width -= sidebarWidth
        var input = PopupLayoutInput(style: style, itemCount: items.count + extraCells,
                                     groupCount: usesSidebar ? 1 : groupIDs.count, maxSize: room)
        if style.layout == .grid, style.labels.mode != .off, LabelFit.needsTwoLines(items, style: style) {
            input.labelLines = 2
        }
        return input
    }

    /// Size the window should have now. With "lock size while swiping" every group gets the largest size.
    func desiredSize() -> CGSize {
        guard let group = currentGroup else { return CGSize(width: 260, height: 160) }
        var size = metrics(for: group).size
        if store.settings.lockSizeWhileSwiping, groupIDs.count > 1, !isInFolder, query.isEmpty {
            for g in groups {
                let m = PopupMetrics.compute(layoutInput(for: g, items: store.visibleItems(of: g)))
                size.width = max(size.width, m.size.width)
                size.height = max(size.height, m.size.height)
            }
        }
        if usesSidebar {
            size.width += sidebarWidth
            size.height = min(max(size.height, sidebarMinHeight), maxSize.height)
        }
        return size
    }

    // MARK: Sidebar

    /// Group list on the left instead of swiping (settings), only when there is more than one group.
    var usesSidebar: Bool { (sidebarOverride ?? (store.settings.popupNavigation == .sidebar)) && groupIDs.count > 1 }

    /// Forces the sidebar on or off (previews), nil = follow the setting.
    var sidebarOverride: Bool?

    var sidebarWidth: CGFloat {
        guard usesSidebar else { return 0 }
        return store.settings.sidebarCollapsed ? PopupSidebar.compactWidth : PopupSidebar.fullWidth
    }

    var sidebarMinHeight: CGFloat {
        PopupSidebar.minHeight(groupCount: groupIDs.count)
    }

    /// Collapse is instant, without animation.
    func toggleSidebar() {
        store.settings.sidebarCollapsed.toggle()
        actions.resizeInstantly()
    }

    // MARK: Navigation

    func pageCounts() -> [Int] {
        groups.enumerated().map { i, g in
            i == position.group ? metrics(for: g).pageCount
                : PopupMetrics.compute(layoutInput(for: g, items: store.visibleItems(of: g))).pageCount
        }
    }

    /// One step through pages, then groups. Disabled inside folders and while searching.
    func step(_ delta: Int) {
        if isInFolder || !query.isEmpty {
            guard let group = currentGroup else { return }
            let count = metrics(for: group).pageCount
            let p = min(max(position.page + delta, 0), count - 1)
            if p != position.page { slideDirection = delta; position.page = p; selection = nil }
            return
        }
        let next = CarouselPosition.step(position, by: delta, pageCounts: pageCounts(), wrap: groupIDs.count > 1)
        guard next != position else { return }
        slideDirection = delta
        let groupChanged = next.group != position.group
        position = next
        selection = nil
        if groupChanged { resetForGroupChange() }
        actions.resize()
    }

    func showGroup(at index: Int) {
        guard groupIDs.indices.contains(index), index != position.group else { return }
        slideDirection = index > position.group ? 1 : -1
        position = CarouselPosition(group: index, page: 0)
        resetForGroupChange()
        actions.resize()
    }

    func showPage(_ page: Int) {
        guard page != position.page else { return }
        slideDirection = page > position.page ? 1 : -1
        position.page = page
        selection = nil
    }

    /// VoiceOver hears the new group's name after a switch.
    func announceGroup() {
        guard NSWorkspace.shared.isVoiceOverEnabled, let name = currentGroup?.name else { return }
        let text = groupIDs.count > 1
            ? String(localized: "\(name), group \(position.group + 1) of \(groupIDs.count)")
            : name
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    private func resetForGroupChange() {
        defer { announceGroup() }
        selection = nil
        picked = []
        query = ""
        folderStack = []
        openAllArmed = false
        renaming = nil
    }

    // MARK: Folders

    func enterFolder(_ url: URL) {
        folderStack.append(FolderLevel(url: url))
        selection = nil
        query = ""
        position.page = 0
        actions.resize()
        let depth = folderStack.count
        Task {
            let items = await Self.listFolder(url)
            guard self.folderStack.count == depth, self.folderStack.last?.url == url else { return }
            self.folderStack[depth - 1].items = items
            self.folderStack[depth - 1].loading = false
            self.actions.resize()
        }
    }

    func leaveFolder() {
        guard !folderStack.isEmpty else { return }
        folderStack.removeLast()
        selection = nil
        position.page = 0
        actions.resize()
    }

    /// Folder contents off the main thread, sorted by name, hidden files skipped.
    nonisolated static func listFolder(_ url: URL) async -> [DockItem] {
        await Task.detached(priority: .userInitiated) {
            let urls = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
            return urls
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .map { DockItem(url: $0) }
        }.value
    }

    // MARK: Selection and launching

    /// Click on an item. Modifiers: ⌘ toggles multi-selection, ⌥ quits a running app.
    func activate(_ item: DockItem, in group: ItemGroup, modifiers: NSEvent.ModifierFlags = []) {
        if modifiers.contains(.command) {
            if picked.contains(item.url) { picked.remove(item.url) } else { picked.insert(item.url) }
            // The header with "Open Selected" may appear or go away.
            actions.resize()
            return
        }
        if modifiers.contains(.option), item.kind == .app, RunningApps.shared.isRunning(item) {
            ItemOpener.quit(item)
            return
        }
        if item.kind == .folder {
            enterFolder(item.url)
            return
        }
        actions.willLaunch()
        ItemOpener.open(item, in: group.id)
        actions.didLaunch()
    }

    func openPicked(in group: ItemGroup) {
        let items = shownItems(of: group).filter { picked.contains($0.url) }
        guard !items.isEmpty else { return }
        picked = []
        actions.resize()
        actions.willLaunch()
        ItemOpener.open(items, in: group.id)
        actions.didLaunch()
    }

    /// "Open All". With confirmation on, the first click arms the button and a second click within 3 s opens.
    func openAll(in group: ItemGroup) {
        if store.settings.confirmBeforeOpenAll, !openAllArmed {
            openAllArmed = true
            armTask?.cancel()
            armTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled { self?.openAllArmed = false }
            }
            return
        }
        openAllArmed = false
        armTask?.cancel()
        let items = baseItems(of: group).filter { $0.kind != .folder || !isInFolder }
        actions.willLaunch()
        ItemOpener.open(items, in: group.id)
        actions.didLaunch()
    }

    /// Plain: hide all, ⌥: quit all, ⌘: force quit all.
    func closeAll(in group: ItemGroup, modifiers: NSEvent.ModifierFlags) {
        let items = baseItems(of: group)
        if modifiers.contains(.command) {
            ItemOpener.quitAll(items, force: true)
        } else if modifiers.contains(.option) {
            ItemOpener.quitAll(items, force: false)
        } else {
            ItemOpener.hideAll(items)
        }
    }

    /// True when the item belongs to a stored group (not a folder listing or a smart group).
    func isEditable(in group: ItemGroup) -> Bool {
        !isInFolder && group.smart == nil
    }
}

/// Hooks from the model to the window that shows it.
struct PopupActions {
    var close: () -> Void = {}
    var resize: () -> Void = {}
    var resizeInstantly: () -> Void = {}
    var quickLook: (DockItem) -> Void = { _ in }
    var togglePin: () -> Void = {}
    /// Called around a launch so focus loss from the launched app does not close a popup that should stay.
    var willLaunch: () -> Void = {}
    var didLaunch: () -> Void = {}
    /// Screen frame of the popup window, for drag-out detection.
    var windowFrame: () -> CGRect? = { nil }
    /// Keeps the popup open while a sheet or picker of the app is up.
    var suspendAutoClose: (Bool) -> Void = { _ in }
}
