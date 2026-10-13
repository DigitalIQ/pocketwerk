import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Root of the main window: sidebar (groups, Dock, settings) and the selected page.
struct MainWindowView: View {
    @Bindable var model: MainWindowModel
    private var store: LibraryStore { LibraryStore.shared }

    var body: some View {
        NavigationSplitView(columnVisibility: $model.columnVisibility) {
            SidebarView(model: model)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 340)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: model.columnVisibility) { _, new in
            let collapsed = new == .detailOnly
            if store.settings.sidebarCollapsed != collapsed { store.settings.sidebarCollapsed = collapsed }
        }
        .frame(minWidth: 720, minHeight: 460)
        .confirmationDialog(deleteTitle, isPresented: deleteBinding, titleVisibility: .visible) {
            Button("Delete Group", role: .destructive) {
                if let id = model.deleteCandidate { delete(id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The group and its Dock icon are removed. You can undo this with ⌘Z.")
        }
    }

    private var deleteTitle: String {
        let name = model.deleteCandidate.flatMap { store.group($0)?.name } ?? ""
        return String(localized: "Delete “\(name)”?")
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { model.deleteCandidate != nil }, set: { if !$0 { model.deleteCandidate = nil } })
    }

    private func delete(_ id: UUID) {
        let order = store.library.orderedGroups
        let index = order.firstIndex { $0.id == id } ?? 0
        store.deleteGroupAndLaunchers(id)
        model.deleteCandidate = nil
        if model.selectedGroupID == id {
            let rest = store.library.orderedGroups
            model.selection = rest.isEmpty ? nil : .group(rest[min(index, rest.count - 1)].id)
        }
    }

    @ViewBuilder private var detail: some View {
        switch model.selection {
        case .group(let id):
            if store.group(id) != nil {
                GroupDetailView(groupID: id, model: model).id(id)
            } else {
                ContentUnavailableView("No Group Selected", systemImage: "square.grid.2x2",
                                       description: Text("Choose a group in the sidebar or press ⌘N."))
            }
        case .dockIcons:
            DockSlotsView()
                .navigationTitle(Text("Dock Icons"))
        case .profiles:
            DockProfilesView()
                .navigationTitle(Text("Dock Profiles"))
        case .settings(let page):
            SettingsPageView(page: page)
                .navigationTitle(Text("Settings"))
        case nil:
            ContentUnavailableView("Pocketwerk", systemImage: "square.grid.2x2",
                                   description: Text("Choose a group in the sidebar or press ⌘N."))
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Bindable var model: MainWindowModel
    private var store: LibraryStore { LibraryStore.shared }
    private var hotkeys: HotkeyCenter { HotkeyCenter.shared }

    var body: some View {
        let lib = store.library
        let badges = Dictionary(HotkeyPlan.bindings(lib).compactMap { b -> (UUID, HotkeyBinding)? in
            if case .group(let id) = b.target { return (id, b) }
            return nil
        }, uniquingKeysWith: { a, _ in a })

        List(selection: $model.selection) {
            Section {
                ForEach(lib.orderedGroups) { group in
                    GroupRow(group: group, badge: badges[group.id], failed: hotkeys.failed.contains(.group(group.id)),
                             model: model)
                        .tag(SidebarItem.group(group.id))
                }
                .onMove { store.moveGroups(from: $0, to: $1) }
            } header: {
                HStack {
                    Text("Groups")
                    Spacer()
                    Menu {
                        Button("New Group") { MainWindowController.shared.newGroup() }
                        Divider()
                        ForEach(SmartGroupKind.allCases, id: \.self) { kind in
                            Button {
                                MainWindowController.shared.newGroup(smart: kind)
                            } label: {
                                Label(SmartGroups.title(kind), systemImage: SmartGroups.symbol(kind))
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    } primaryAction: {
                        MainWindowController.shared.newGroup()
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("New group (⌘N)")
                    .accessibilityLabel(Text("New group"))
                }
            }

            Section("Dock") {
                Label("Dock Icons", systemImage: "dock.rectangle").tag(SidebarItem.dockIcons)
                Label("Profiles", systemImage: "square.stack.3d.up").tag(SidebarItem.profiles)
            }

            Section("Settings") {
                ForEach(SettingsPage.allCases) { page in
                    Label(page.title, systemImage: page.symbol).tag(SidebarItem.settings(page))
                }
            }
        }
        .listStyle(.sidebar)
        .onDeleteCommand {
            if let id = model.selectedGroupID { model.deleteCandidate = id }
        }
        .onKeyPress(.return) {
            guard let id = model.selectedGroupID, model.renamingGroupID == nil else { return .ignored }
            model.renamingGroupID = id
            return .handled
        }
        .safeAreaInset(edge: .bottom) { UpdateNotice().padding(10) }
    }
}

/// One group in the sidebar: emoji, name (renamable inline), pin and hotkey badges, drop target.
struct GroupRow: View {
    let group: ItemGroup
    let badge: HotkeyBinding?
    let failed: Bool
    @Bindable var model: MainWindowModel
    @State private var draft = ""
    @State private var targeted = false
    @FocusState private var focused: Bool
    private var store: LibraryStore { LibraryStore.shared }

    var body: some View {
        HStack(spacing: 8) {
            GroupGlyph(group: group)
            if model.renamingGroupID == group.id {
                TextField("Name", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onAppear { draft = group.name; focused = true }
                    .onSubmit(commit)
                    .onExitCommand { model.renamingGroupID = nil }
                    .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
            } else {
                Text(group.name).lineLimit(1)
            }
            Spacer(minLength: 4)
            if group.hiddenFromAll {
                Image(systemName: "eye.slash").foregroundStyle(.secondary).help("Hidden from All Groups")
                    .accessibilityLabel(Text("Hidden from All Groups"))
            }
            if group.pinned {
                Image(systemName: "pin.fill").font(.caption).foregroundStyle(.secondary).help("Pinned")
                    .accessibilityLabel(Text("Pinned"))
            }
            if let badge {
                Text(HotkeyCenter.describe(badge.hotkey))
                    .font(.caption.monospaced())
                    .foregroundStyle(failed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                    .help(failed ? "Another app uses this shortcut" : (badge.isDefault ? "Automatic shortcut" : "Shortcut"))
            }
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .background(targeted ? Color.accentColor.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 5))
        .onDrop(of: group.smart == nil ? ItemDrag.acceptedTypes : [], isTargeted: $targeted) { providers in
            let target = group.id
            Task {
                let payloads = await ItemDrag.payloads(providers)
                ItemDrag.apply(payloads, to: target, at: nil)
            }
            return true
        }
        .contextMenu { menu }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text("Rename")) { model.renamingGroupID = group.id }
    }

    private func commit() {
        guard model.renamingGroupID == group.id else { return }
        store.renameGroup(group.id, to: draft)
        model.renamingGroupID = nil
    }

    @ViewBuilder private var menu: some View {
        Button("Rename") { model.renamingGroupID = group.id }
        Button(group.pinned ? "Unpin" : "Pin to Top") {
            store.updateGroup(group.id) { $0.pinned.toggle() }
        }
        Button(group.hiddenFromAll ? "Show in All Groups" : "Hide from All Groups") {
            store.updateGroup(group.id) { $0.hiddenFromAll.toggle() }
        }
        Divider()
        Button("Show Group") { PopupController.shared.toggle(groupIDs: [group.id], slotID: nil) }
        Button("Open All") { OpenAllAction.run(group) }
        Divider()
        Button("Delete…", role: .destructive) { model.deleteCandidate = group.id }
    }
}

/// Emoji, or a symbol when the group has none.
struct GroupGlyph: View {
    let group: ItemGroup
    var size: CGFloat = 15

    var body: some View {
        Group {
            if let emoji = group.emoji, !emoji.isEmpty {
                Text(emoji).font(.system(size: size))
            } else if let smart = group.smart {
                Image(systemName: SmartGroups.symbol(smart)).foregroundStyle(.yellow)
            } else {
                Image(systemName: "square.grid.2x2").foregroundStyle(GroupColor.swatch(for: group).color)
            }
        }
        .frame(width: size + 6)
        .accessibilityHidden(true)
    }
}

/// Small notice when a newer version exists. Dismissable, never modal.
struct UpdateNotice: View {
    private var checker: UpdateChecker { UpdateChecker.shared }

    var body: some View {
        if let release = checker.available {
            VStack(alignment: .leading, spacing: 6) {
                Label("Version \(release.version) is available", systemImage: "arrow.down.circle")
                    .font(.callout)
                HStack {
                    Button("Download") { checker.openAvailable() }
                    Button("Skip") { checker.skipAvailable() }
                }
                .controlSize(.small)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Drag and drop

/// Drags of items between and inside groups, plus files and links from other apps.
enum ItemDrag {
    static let typeID = "io.github.digitaliq.pocketwerk.item"
    static let type = UTType(exportedAs: typeID, conformingTo: .data)
    static var acceptedTypes: [UTType] { [type, .fileURL, .url] }

    enum Payload: Sendable {
        case item(group: UUID, item: UUID)
        case url(URL)
    }

    /// Provider for an item row: our own type inside the app, the URL for Finder and other apps.
    static func provider(for item: DockItem, in groupID: UUID) -> NSItemProvider {
        let provider = NSItemProvider(object: item.url as NSURL)
        let token = Data("\(groupID.uuidString)/\(item.id.uuidString)".utf8)
        provider.registerDataRepresentation(forTypeIdentifier: typeID, visibility: .ownProcess) { done in
            done(token, nil)
            return nil
        }
        provider.suggestedName = item.displayName
        return provider
    }

    static func payloads(_ providers: [NSItemProvider]) async -> [Payload] {
        var out: [Payload] = []
        for p in providers {
            if p.hasItemConformingToTypeIdentifier(typeID) {
                let data: Data? = await withCheckedContinuation { c in
                    _ = p.loadDataRepresentation(forTypeIdentifier: typeID) { data, _ in c.resume(returning: data) }
                }
                let parts = data.flatMap { String(data: $0, encoding: .utf8) }?.split(separator: "/") ?? []
                if parts.count == 2, let g = UUID(uuidString: String(parts[0])), let i = UUID(uuidString: String(parts[1])) {
                    out.append(.item(group: g, item: i))
                }
            } else if p.canLoadObject(ofClass: NSURL.self) {
                let url: URL? = await withCheckedContinuation { c in
                    _ = p.loadObject(ofClass: NSURL.self) { obj, _ in c.resume(returning: (obj as? NSURL) as URL?) }
                }
                if let url { out.append(.url(url)) }
            }
        }
        return out
    }

    /// Reorders, moves between groups, or adds new items. `index` refers to the shown (sorted) list.
    static func apply(_ payloads: [Payload], to groupID: UUID, at index: Int?) {
        let store = LibraryStore.shared
        var urls: [URL] = []
        var offset = 0
        for p in payloads {
            switch p {
            case .item(let source, let itemID):
                if source == groupID {
                    if let index { store.reorderItem(itemID, in: groupID, to: index + offset) }
                } else {
                    let at = index.map { storageIndex(forShown: $0 + offset, in: groupID) }
                    store.moveItem(itemID, from: source, to: groupID, at: at)
                    offset += 1
                }
            case .url(let url):
                urls.append(url)
            }
        }
        if !urls.isEmpty {
            store.insertURLs(urls, into: groupID, at: index.map { storageIndex(forShown: $0 + offset, in: groupID) })
        }
    }

    /// Shown index -> stored index. Only meaningful for manual order; otherwise items are appended.
    private static func storageIndex(forShown index: Int, in groupID: UUID) -> Int {
        guard let g = LibraryStore.shared.group(groupID), g.sortOrder == .manual else { return Int.max }
        return min(index, g.items.count)
    }
}
