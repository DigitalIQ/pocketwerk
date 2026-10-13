import AppKit
import SwiftUI

/// Editor for one group: header (emoji, name), tabs Items / Appearance / Options.
struct GroupDetailView: View {
    let groupID: UUID
    @Bindable var model: MainWindowModel
    private var store: LibraryStore { LibraryStore.shared }

    var body: some View {
        if let group = store.group(groupID) {
            VStack(spacing: 0) {
                GroupHeader(group: group)
                    .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 10)
                Picker("Section", selection: $model.groupTab) {
                    Text("Items").tag(GroupTab.items)
                    Text("Appearance").tag(GroupTab.appearance)
                    Text("Options").tag(GroupTab.options)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 360)
                .padding(.bottom, 10)
                Divider()
                switch model.groupTab {
                case .items:
                    if let smart = group.smart {
                        SmartItemsView(group: group, kind: smart)
                    } else {
                        ItemListView(group: group)
                    }
                case .appearance:
                    DesignStudioView(groupID: groupID)
                case .options:
                    GroupOptionsView(group: group, model: model)
                }
            }
            .toolbar { toolbar(group) }
            .sheet(isPresented: $model.showAppDrawer) { AppDrawerView(groupID: groupID) }
            .sheet(isPresented: $model.showAddLink) { AddLinkSheet(groupID: groupID) }
            .navigationTitle(group.name)
        }
    }

    @ToolbarContentBuilder
    private func toolbar(_ group: ItemGroup) -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if group.smart == nil {
                Button { model.showAppDrawer = true } label: { Label("Add Apps", systemImage: "square.grid.3x3.square") }
                    .help("Add apps from the App Drawer")
                Button { MainWindowController.shared.addFiles() } label: { Label("Add Files", systemImage: "doc.badge.plus") }
                    .help("Add files or folders (⇧⌘F)")
                Button { model.showAddLink = true } label: { Label("Add Link", systemImage: "link.badge.plus") }
                    .help("Add a web link")
                Menu {
                    Picker("Sort By", selection: Binding(get: { group.sortOrder },
                                                         set: { v in store.updateGroup(group.id) { $0.sortOrder = v } })) {
                        ForEach(SortOrder.allCases, id: \.self) { Text(SortOrderName.title($0)).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .help("Sort order")
            }
            Button { PopupController.shared.toggle(groupIDs: [group.id], slotID: nil) } label: {
                Label("Show Group", systemImage: "rectangle.portrait.on.rectangle.portrait")
            }
            .help("Show this group as a popup")
        }
    }
}

enum SortOrderName {
    static func title(_ order: SortOrder) -> String {
        switch order {
        case .manual: String(localized: "Manual")
        case .name: String(localized: "Name")
        case .kind: String(localized: "Kind")
        case .dateAdded: String(localized: "Date Added")
        case .lastOpened: String(localized: "Last Opened")
        case .mostOpened: String(localized: "Most Opened")
        }
    }
}

/// Emoji picker and inline name field.
struct GroupHeader: View {
    let group: ItemGroup
    @State private var name = ""
    @State private var showEmoji = false
    @FocusState private var nameFocused: Bool
    private var store: LibraryStore { LibraryStore.shared }

    var body: some View {
        HStack(spacing: 12) {
            Button { showEmoji = true } label: {
                GroupGlyph(group: group, size: 28).frame(width: 40, height: 40)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .help("Choose an emoji")
            .accessibilityLabel(Text("Emoji"))
            .accessibilityValue(Text(group.emoji ?? String(localized: "None")))
            .popover(isPresented: $showEmoji, arrowEdge: .bottom) { EmojiPicker(groupID: group.id) }

            TextField("Group name", text: $name)
                .textFieldStyle(.plain)
                .font(.title2.weight(.semibold))
                .focused($nameFocused)
                .onSubmit { store.renameGroup(group.id, to: name) }
                .onChange(of: nameFocused) { _, focused in if !focused { store.renameGroup(group.id, to: name) } }
                .accessibilityLabel(Text("Group name"))
            Spacer()
            if group.smart == nil {
                Text("\(group.items.count) items").foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .onAppear { name = group.name }
        .onChange(of: group.name) { _, new in if !nameFocused { name = new } }
    }
}

/// Quick emoji choice plus the system character palette.
struct EmojiPicker: View {
    let groupID: UUID
    @State private var custom = ""
    private var store: LibraryStore { LibraryStore.shared }
    private let choices = ["💼", "🎨", "🧰", "🎮", "🎵", "📚", "🧪", "💻", "📷", "🎬", "✍️", "📈",
                           "🛠️", "🌐", "📁", "🗂️", "🧠", "🏠", "✈️", "🍳", "⭐️", "🔥", "🌿", "🚀"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30)), count: 8), spacing: 6) {
                ForEach(choices, id: \.self) { e in
                    Button { set(e) } label: { Text(e).font(.title3) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(e))
                }
            }
            HStack {
                TextField("Other", text: $custom).frame(width: 70)
                    .onSubmit { if let first = custom.first { set(String(first)) } }
                Button("Emoji & Symbols") { NSApp.orderFrontCharacterPalette(nil) }
                Spacer()
                Button("None") { set(nil) }
            }
            .controlSize(.small)
        }
        .padding(12)
    }

    private func set(_ emoji: String?) {
        store.updateGroup(groupID) { $0.emoji = emoji }
    }
}

// MARK: - Items

struct ItemListView: View {
    let group: ItemGroup
    @State private var selection = Set<UUID>()
    @State private var renaming: UUID?
    private var store: LibraryStore { LibraryStore.shared }
    private var health: LibraryHealth { LibraryHealth.shared }

    var body: some View {
        let items = group.sortedItems
        List(selection: $selection) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ItemRow(item: item, groupID: group.id, missing: health.missing.contains(item.id), renaming: $renaming)
                    .tag(item.id)
                    .onDrag { ItemDrag.provider(for: item, in: group.id) }
                    .contextMenu { menu(for: item, index: index, count: items.count) }
            }
            .onInsert(of: ItemDrag.acceptedTypes) { index, providers in
                let id = group.id
                Task {
                    let payloads = await ItemDrag.payloads(providers)
                    ItemDrag.apply(payloads, to: id, at: index)
                }
            }
        }
        .overlay {
            if items.isEmpty { emptyState }
        }
        .onDeleteCommand { store.removeItems(selection, from: group.id); selection = [] }
        .onKeyPress(.return) {
            guard selection.count == 1, renaming == nil else { return .ignored }
            renaming = selection.first
            return .handled
        }
        .safeAreaInset(edge: .bottom) {
            if !missingHere.isEmpty {
                HStack {
                    Label("\(missingHere.count) items can no longer be found", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Remove Missing") { store.removeItems(missingHere, from: group.id) }
                }
                .padding(10)
                .background(.bar)
            }
        }
    }

    private var missingHere: Set<UUID> { Set(group.items.map(\.id)).intersection(health.missing) }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down").font(.system(size: 34)).foregroundStyle(.secondary)
            Text("Drop apps, files or folders here").font(.headline)
            HStack {
                Button("Add Apps…") { MainWindowController.shared.showAppDrawer() }
                Button("Add Files…") { MainWindowController.shared.addFiles() }
                Button("Add Link…") { MainWindowController.shared.addLink() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onDrop(of: ItemDrag.acceptedTypes, isTargeted: nil) { providers in
            let id = group.id
            Task { ItemDrag.apply(await ItemDrag.payloads(providers), to: id, at: nil) }
            return true
        }
    }

    @ViewBuilder private func menu(for item: DockItem, index: Int, count: Int) -> some View {
        let targets = selection.contains(item.id) && selection.count > 1 ? selection : [item.id]
        Button("Open") { ItemOpener.open(item, in: group.id) }
        if item.kind != .link {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
        }
        Divider()
        Button("Rename") { renaming = item.id }
        if item.customName != nil {
            Button("Use Original Name") { store.renameItem(item.id, in: group.id, to: "") }
        }
        Menu("Move To") {
            ForEach(store.library.regularGroups.filter { $0.id != group.id }) { other in
                Button([other.emoji, other.name].compactMap { $0 }.joined(separator: " ")) {
                    for id in targets { store.moveItem(id, from: group.id, to: other.id) }
                }
            }
        }
        Button("Move Up") { store.reorderItem(item.id, in: group.id, to: index - 1) }.disabled(index == 0)
        Button("Move Down") { store.reorderItem(item.id, in: group.id, to: index + 2) }.disabled(index >= count - 1)
        Divider()
        Button(targets.count > 1 ? "Remove \(targets.count) Items" : "Remove from Group", role: .destructive) {
            store.removeItems(targets, from: group.id)
            selection.subtract(targets)
        }
    }
}

struct ItemRow: View {
    let item: DockItem
    let groupID: UUID
    let missing: Bool
    @Binding var renaming: UUID?
    @State private var draft = ""
    @FocusState private var focused: Bool
    private var store: LibraryStore { LibraryStore.shared }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: IconRenderer.icon(for: item, size: 32))
                .resizable().frame(width: 32, height: 32)
                .opacity(missing ? 0.4 : 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                if renaming == item.id {
                    TextField("Name", text: $draft, prompt: Text(originalName))
                        .textFieldStyle(.roundedBorder)
                        .focused($focused)
                        .onAppear { draft = item.customName ?? ""; focused = true }
                        .onSubmit(commit)
                        .onExitCommand { renaming = nil }
                        .onChange(of: focused) { _, f in if !f { commit() } }
                        .accessibilityHint(Text("Leave empty to use the original name"))
                } else {
                    Text(item.displayName).lineLimit(1)
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if missing {
                Label("Missing", systemImage: "exclamationmark.triangle.fill")
                    .labelStyle(.iconOnly).foregroundStyle(.orange)
                    .help("This item can no longer be found")
            }
            if item.openCount > 0 {
                Text("\(item.openCount)×").font(.caption).foregroundStyle(.tertiary).monospacedDigit()
                    .help("Times opened")
            }
            Text(kindName).font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text("Rename")) { renaming = item.id }
    }

    private var originalName: String {
        var copy = item
        copy.customName = nil
        return copy.displayName
    }

    private var subtitle: String {
        if item.customName != nil { return originalName }
        switch item.kind {
        case .link: return item.url.absoluteString
        default: return (item.url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
        }
    }

    private var kindName: String {
        switch item.kind {
        case .app: String(localized: "App")
        case .file: String(localized: "File")
        case .folder: String(localized: "Folder")
        case .link: String(localized: "Link")
        }
    }

    private func commit() {
        guard renaming == item.id else { return }
        store.renameItem(item.id, in: groupID, to: draft)
        renaming = nil
    }
}

/// Computed items of a smart group, read only.
struct SmartItemsView: View {
    let group: ItemGroup
    let kind: SmartGroupKind
    private var store: LibraryStore { LibraryStore.shared }

    var body: some View {
        let items = store.visibleItems(of: group)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(explanation).foregroundStyle(.secondary)
                Spacer()
                if kind != .runningApps {
                    Stepper("Show \(group.smartLimit)", value: Binding(get: { group.smartLimit },
                                                                     set: { v in store.updateGroup(group.id) { $0.smartLimit = v } }),
                            in: 3...40)
                }
            }
            .padding(14)
            Divider()
            List(items) { item in
                HStack(spacing: 10) {
                    Image(nsImage: IconRenderer.icon(for: item, size: 28)).resizable().frame(width: 28, height: 28)
                        .accessibilityHidden(true)
                    Text(item.displayName)
                    Spacer()
                    if let bid = item.bundleID, let n = store.library.usage.launches[bid], kind == .mostUsed {
                        Text("\(n + item.openCount)×").foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView("Nothing Yet", systemImage: SmartGroups.symbol(kind),
                                           description: Text("This group fills itself as you use your Mac."))
                }
            }
        }
    }

    private var explanation: String {
        switch kind {
        case .mostUsed: String(localized: "Apps you launch most, counted on this Mac only.")
        case .recentlyOpened: String(localized: "Items and apps you opened most recently.")
        case .runningApps: String(localized: "Apps that are running right now.")
        }
    }
}

// MARK: - Options

struct GroupOptionsView: View {
    let group: ItemGroup
    @Bindable var model: MainWindowModel
    private var store: LibraryStore { LibraryStore.shared }

    var body: some View {
        let lib = store.library
        let effective = HotkeyPlan.effectiveHotkey(forGroup: group.id, in: lib)
        Form {
            Section {
                if group.smart == nil {
                    Picker("Sort items by", selection: bind(\.sortOrder)) {
                        ForEach(SortOrder.allCases, id: \.self) { Text(SortOrderName.title($0)).tag($0) }
                    }
                }
                LabeledContent("Shortcut") {
                    HotkeyRecorder(hotkey: bind(\.hotkey), target: .group(group.id),
                                   placeholder: effective?.isDefault == true ? HotkeyCenter.describe(effective!.hotkey) : nil)
                }
                if group.hotkey == nil, effective?.isDefault == true {
                    Text("Uses the automatic shortcut for its position in the sidebar.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if HotkeyCenter.shared.failed.contains(.group(group.id)) {
                    Text("Another app already uses this shortcut. Choose a different one.")
                        .font(.caption).foregroundStyle(.red)
                }
            }
            Section {
                Toggle("Pin to top of the sidebar", isOn: bind(\.pinned))
                Toggle("Hide from All Groups", isOn: bind(\.hiddenFromAll))
                Text("Hidden groups stay reachable by their own Dock icon and shortcut.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Use default look", isOn: bind(\.usesDefaultStyle))
            }
            Section {
                Button("Delete Group…", role: .destructive) { model.deleteCandidate = group.id }
            }
        }
        .formStyle(.grouped)
    }

    private func bind<T>(_ path: WritableKeyPath<ItemGroup, T>) -> Binding<T> {
        Binding(get: { store.group(group.id)?[keyPath: path] ?? group[keyPath: path] },
                set: { v in store.updateGroup(group.id) { $0[keyPath: path] = v } })
    }
}
