import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// One group as the popup shows it: background, border, header, items in grid/list/tiles.
/// Sizes itself to its content (adaptive layout). `preview: true` is used by the Design Studio:
/// no launching, no keyboard focus, but everything else looks exactly like the real popup.
struct PopupGroupView: View {
    let group: ItemGroup
    var preview: Bool = false
    /// Shared state of a real popup window; nil = own state (preview).
    var model: PopupModel?
    /// Fixed card size (the window size); nil = own content size.
    var size: CGSize?

    @State private var ownModel = PopupModel(groupIDs: [])

    init(group: ItemGroup, preview: Bool = false) {
        self.group = group
        self.preview = preview
    }

    init(group: ItemGroup, model: PopupModel, size: CGSize?) {
        self.group = group
        self.preview = false
        self.model = model
        self.size = size
    }

    var body: some View {
        let m = model ?? ownModel
        PopupCard(group: group, model: m, preview: preview, size: size)
            .onAppear {
                if model == nil, ownModel.groupIDs != [group.id] { ownModel.groupIDs = [group.id] }
            }
    }
}

/// Root view of a popup window: the current group, sliding when the carousel moves.
struct PopupRootView: View {
    let model: PopupModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let group = model.currentGroup {
                PopupGroupView(group: group, model: model, size: model.panelSize)
                    .id(group.id)
                    .transition(reduceMotion ? .opacity : .push(from: model.slideDirection > 0 ? .trailing : .leading))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Card

struct PopupCard: View {
    let group: ItemGroup
    let model: PopupModel
    let preview: Bool
    let size: CGSize?

    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private var store: LibraryStore { .shared }

    var body: some View {
        let style = store.popupStyle(of: group)
        let scheme: ColorScheme = style.appearance == .light ? .light : (style.appearance == .dark ? .dark : systemScheme)
        let metrics = model.metrics(for: group)
        let cardSize = size ?? metrics.size
        let radius = CGFloat(style.cornerRadius * style.popupScale)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let background = reduceTransparency ? PopupLook.opaque(style.background, dark: scheme == .dark) : style.background
        let lightText = PopupLook.prefersLightText(background, dark: scheme == .dark)
        let surfaceStyle = { var s = style; s.background = background; return s }()

        VStack(spacing: 0) {
            if metrics.headerHeight > 0 {
                PopupHeader(group: group, style: style, model: model, preview: preview, lightText: lightText, metrics: metrics)
                    .frame(height: metrics.headerHeight)
                    .padding(.top, metrics.padding / 2)
            }
            PopupItemsArea(group: group, style: style, model: model, preview: preview, lightText: lightText, metrics: metrics)
                .padding(.top, metrics.headerHeight > 0 ? metrics.padding / 2 : metrics.padding)
                .padding(.horizontal, metrics.padding)
                .padding(.bottom, metrics.dotsHeight > 0 ? 0 : metrics.padding)
            if metrics.dotsHeight > 0 {
                PopupDots(group: group, model: model, metrics: metrics, lightText: lightText)
                    .frame(height: metrics.dotsHeight)
                    .padding(.bottom, metrics.padding * 0.6)
            }
            Spacer(minLength: 0)
        }
        .frame(width: cardSize.width, height: cardSize.height, alignment: .top)
        .background {
            ZStack {
                // The style init applies glass amount, matte and opacity on top of the fill.
                StyleBackgroundView(style: surfaceStyle, pointer: model.pointer,
                                    isActive: (preview || model.isVisible) && !ProcessInfo.processInfo.isLowPowerModeEnabled)
            }
            .contentShape(shape)
            .gesture(swipeGesture)
            .overlay { if !preview { BackgroundMenuArea(group: group, model: model) } }
        }
        .clipShape(shape)
        .overlay { border(style: style, shape: shape) }
        .shadow(color: preview && style.shadow ? .black.opacity(0.25) : .clear, radius: 18, y: 8)
        .environment(\.colorScheme, scheme)
        .onContinuousHover { phase in
            switch phase {
            case .active(let p): model.pointer = p
            case .ended: model.pointer = nil
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(group.name)
    }

    @ViewBuilder
    private func border(style: GroupStyle, shape: RoundedRectangle) -> some View {
        let strong = contrast == .increased
        if let b = style.border, b.width > 0 || strong {
            let width = max(b.width, strong ? 1.5 : 0) * style.popupScale
            if let g = b.gradient, g.count >= 2 {
                shape.strokeBorder(LinearGradient(colors: g.map(\.color), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: width)
            } else {
                shape.strokeBorder(b.color.color.opacity(strong ? max(b.color.a, 0.7) / max(b.color.a, 0.01) : 1), lineWidth: width)
            }
        } else if strong {
            shape.strokeBorder(Color.primary.opacity(0.6), lineWidth: 1.5)
        }
    }

    /// Click-and-drag on the background moves between pages and groups.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onEnded { value in
                let dx = value.translation.width, dy = value.translation.height
                guard abs(dx) > 50, abs(dx) > abs(dy) else { return }
                withPopupAnimation { model.step(dx < 0 ? 1 : -1) }
            }
    }
}

/// Right-click on the popup background.
private struct BackgroundMenuArea: NSViewRepresentable {
    let group: ItemGroup
    let model: PopupModel

    func makeNSView(context: Context) -> MenuView { MenuView() }
    func updateNSView(_ nsView: MenuView, context: Context) {
        nsView.makeMenu = { ItemMenu.backgroundMenu(group: group, model: model) }
    }

    final class MenuView: NSView {
        var makeMenu: (() -> NSMenu)?
        override func menu(for event: NSEvent) -> NSMenu? { makeMenu?() }
        // Only right clicks are taken; left clicks and drags reach SwiftUI below.
        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let e = NSApp.currentEvent, e.type == .rightMouseDown || (e.type == .leftMouseDown && e.modifierFlags.contains(.control)) else { return nil }
            return super.hitTest(point)
        }
    }
}

// MARK: - Header

struct PopupHeader: View {
    let group: ItemGroup
    let style: GroupStyle
    let model: PopupModel
    let preview: Bool
    let lightText: Bool
    let metrics: PopupMetrics

    private var color: Color { PopupLook.labelColor(style.labels, lightText: lightText) }
    /// A hidden header that is shown anyway (folder, search, pinned) puts the title on the left.
    private var alignment: HeaderAlignment { style.header == .hidden ? .leading : style.header }
    private var scale: CGFloat { CGFloat(style.popupScale) }

    var body: some View {
        ZStack {
            if model.pinned && !preview { WindowDragArea() }
            HStack(spacing: 6 * scale) {
                if model.isInFolder {
                    iconButton("chevron.left", help: String(localized: "Back")) { withPopupAnimation { model.leaveFolder() } }
                }
                if alignment == .leading { title }
                if !model.query.isEmpty { searchPill }
                Spacer(minLength: 4)
                actions
            }
            if alignment == .center {
                title.frame(maxWidth: metrics.size.width * 0.5)
            }
        }
        .padding(.horizontal, metrics.padding * 0.8)
        .foregroundStyle(color)
    }

    private var titleText: String {
        model.folderStack.last?.name ?? group.name
    }

    @ViewBuilder
    private var title: some View {
        let font = PopupLook.font(style.labels, size: 13 * scale, weightBoost: 0.15)
        if !preview, model.groupIDs.count > 1, !model.isInFolder {
            // Quick switcher.
            Menu {
                ForEach(Array(model.groups.enumerated()), id: \.element.id) { i, g in
                    Button {
                        withPopupAnimation { model.showGroup(at: i) }
                    } label: {
                        if i == model.position.group { Label(g.name, systemImage: "checkmark") } else { Text(g.name) }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(titleText).font(font).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 9 * scale, weight: .semibold)).opacity(0.7)
                }
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityLabel(Text("Group \(titleText). Switch group"))
        } else {
            Text(titleText).font(font).lineLimit(1).truncationMode(.middle)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var searchPill: some View {
        HStack(spacing: 3) {
            Image(systemName: "magnifyingglass").font(.system(size: 10 * scale))
            Text(model.query).font(.system(size: 11 * scale, weight: .medium)).lineLimit(1)
            Button {
                model.query = ""
                model.selection = nil
                model.actions.resize()
            } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 10 * scale)) }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.14)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Search: \(model.query)"))
    }

    @ViewBuilder
    private var actions: some View {
        let items = preview ? store.visibleItems(of: group) : model.baseItems(of: group)
        let hasApps = items.contains { $0.kind == .app }
        if !model.picked.isEmpty {
            Button {
                model.openPicked(in: group)
            } label: {
                Text("Open \(model.picked.count)").font(.system(size: 11 * scale, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .help("Open the selected items")
        }
        if !items.isEmpty {
            if model.openAllArmed {
                Button { model.openAll(in: group) } label: {
                    Text("Open \(items.count)?").font(.system(size: 11 * scale, weight: .semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .help("Click again to open all items")
            } else {
                iconButton("arrow.up.right.square", help: String(localized: "Open All")) { model.openAll(in: group) }
            }
        }
        if hasApps {
            let mods = model.modifiers
            let (symbol, help): (String, String) = mods.contains(.command)
                ? ("bolt.circle", String(localized: "Force Quit All"))
                : mods.contains(.option) ? ("xmark.circle", String(localized: "Quit All")) : ("eye.slash", String(localized: "Hide All (⌥ Quit, ⌘ Force Quit)"))
            iconButton(symbol, help: help) { model.closeAll(in: group, modifiers: NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)) }
        }
        if !preview {
            iconButton(model.pinned ? "xmark" : "pin", help: model.pinned ? String(localized: "Close") : String(localized: "Keep Open as Window")) {
                model.actions.togglePin()
            }
        }
    }

    private var store: LibraryStore { .shared }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: { if !preview { action() } }) {
            Image(systemName: symbol)
                .font(.system(size: 11 * scale, weight: .semibold))
                .frame(width: 22 * scale, height: 22 * scale)
                .background(Circle().fill(color.opacity(0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

// MARK: - Items

struct PopupItemsArea: View {
    let group: ItemGroup
    let style: GroupStyle
    let model: PopupModel
    let preview: Bool
    let lightText: Bool
    let metrics: PopupMetrics

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let items = model.shownItems(of: group)
        var cells: [PopupCellContent] = items.map { .item($0) }
        if let folder = model.folderStack.last, !folder.loading { cells.append(.openInFinder(folder.url)) }
        let range = metrics.pageRange(model.position.page, itemCount: cells.count)

        return ZStack(alignment: .top) {
            if cells.isEmpty || (cells.count == 1 && model.isInFolder && model.folderStack.last?.items.isEmpty == true && !model.query.isEmpty) {
                placeholder
            } else if metrics.scrolls {
                ScrollView(.vertical) {
                    grid(cells, range: 0..<cells.count)
                }
                .scrollIndicators(.automatic)
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in scrollOffset = y }
            } else {
                grid(cells, range: range)
                    .id(model.position.page)
                    .transition(reduceMotion ? .opacity : .push(from: model.slideDirection > 0 ? .trailing : .leading))
            }
        }
        .frame(width: metrics.gridSize.width, height: metrics.gridSize.height, alignment: .top)
        .clipped()
        .modifier(DropTarget(enabled: !preview, delegate: PopupDropDelegate(
            group: group, model: model, metrics: metrics, items: items,
            pageStart: metrics.scrolls ? 0 : range.lowerBound, scrollOffset: scrollOffset, enabled: !preview)))
    }

    @State private var scrollOffset: CGFloat = 0

    private func grid(_ cells: [PopupCellContent], range: Range<Int>) -> some View {
        let columns = Array(repeating: GridItem(.fixed(metrics.cell.width), spacing: metrics.gap, alignment: .top), count: metrics.columns)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: metrics.gap) {
            ForEach(range, id: \.self) { i in
                PopupItemCell(content: cells[i], index: i, group: group, style: style, metrics: metrics,
                              model: model, preview: preview, lightText: lightText)
                    .overlay(alignment: .leading) { insertionMark(at: i, offset: -(metrics.gap + 3) / 2) }
                    .overlay(alignment: .trailing) {
                        if i == range.upperBound - 1 { insertionMark(at: i + 1, offset: (metrics.gap + 3) / 2) }
                    }
            }
        }
        .frame(width: metrics.gridSize.width, alignment: .topLeading)
    }

    @ViewBuilder
    private func insertionMark(at index: Int, offset: CGFloat) -> some View {
        if model.dropIndex == index, model.dropOnItem == nil {
            Capsule().fill(Color.accentColor)
                .frame(width: 3, height: metrics.cell.height * 0.7)
                .offset(x: offset)
                .accessibilityHidden(true)
        }
    }

    private var placeholder: some View {
        let text: LocalizedStringKey
        if model.folderStack.last?.loading == true { text = "Loading…" }
        else if !model.query.isEmpty { text = "No matches" }
        else if model.isInFolder { text = "Empty folder" }
        else if group.smart != nil { text = "Nothing here yet" }
        else { text = "Drop apps, files or links here" }
        return Text(text)
            .font(PopupLook.font(style.labels, size: metrics.labelSize + 1))
            .foregroundStyle(PopupLook.labelColor(style.labels, lightText: lightText).opacity(0.7))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Drop support only for real popups; previews stay plain SwiftUI so they render offscreen.
private struct DropTarget: ViewModifier {
    let enabled: Bool
    let delegate: PopupDropDelegate

    func body(content: Content) -> some View {
        if enabled {
            content.onDrop(of: [.fileURL, .url], delegate: delegate)
        } else {
            content
        }
    }
}

// MARK: - Page and group dots

struct PopupDots: View {
    let group: ItemGroup
    let model: PopupModel
    let metrics: PopupMetrics
    let lightText: Bool

    var body: some View {
        let color: Color = lightText ? .white : .black
        let groups = model.isInFolder || !model.query.isEmpty ? 1 : model.groupIDs.count
        HStack(spacing: 8) {
            if groups > 1 || metrics.pageCount > 1 {
                arrow("chevron.left", delta: -1, color: color)
            }
            if groups > 1 {
                HStack(spacing: 5) {
                    ForEach(0..<groups, id: \.self) { i in
                        dot(active: i == model.position.group, color: color, label: Text("Group \(i + 1) of \(groups)")) {
                            withPopupAnimation { model.showGroup(at: i) }
                        }
                    }
                }
            }
            if metrics.pageCount > 1 {
                if groups > 1 { Capsule().fill(color.opacity(0.3)).frame(width: 1, height: 8) }
                HStack(spacing: 4) {
                    ForEach(0..<metrics.pageCount, id: \.self) { p in
                        dot(active: p == model.position.page, color: color, small: true, label: Text("Page \(p + 1) of \(metrics.pageCount)")) {
                            withPopupAnimation { model.showPage(p) }
                        }
                    }
                }
            }
            if groups > 1 || metrics.pageCount > 1 {
                arrow("chevron.right", delta: 1, color: color)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func dot(active: Bool, color: Color, small: Bool = false, label: Text, action: @escaping () -> Void) -> some View {
        let d: CGFloat = small ? 5 : 7
        return Button(action: action) {
            Capsule()
                .fill(color.opacity(active ? 0.9 : 0.3))
                .frame(width: active && !small ? d * 2 : d, height: d)
                .padding(3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func arrow(_ symbol: String, delta: Int, color: Color) -> some View {
        Button {
            withPopupAnimation { model.step(delta) }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color.opacity(0.6))
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta < 0 ? Text("Previous") : Text("Next"))
    }
}

// MARK: - Drop

/// Drops into the open popup: add apps, files, folders and links at the drop position,
/// reorder items dragged inside the popup, or open files with the app tile they land on.
struct PopupDropDelegate: DropDelegate {
    let group: ItemGroup
    let model: PopupModel
    let metrics: PopupMetrics
    let items: [DockItem]
    let pageStart: Int
    let scrollOffset: CGFloat
    let enabled: Bool

    private var isInternal: Bool { model.dragging != nil }

    func validateDrop(info: DropInfo) -> Bool {
        enabled && (model.isEditable(in: group) || target(info).onItem != nil)
    }

    func dropEntered(info: DropInfo) { update(info) }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        update(info)
        if !model.isEditable(in: group) { return DropProposal(operation: model.dropOnItem != nil ? .copy : .forbidden) }
        return DropProposal(operation: isInternal ? .move : .copy)
    }

    func dropExited(info: DropInfo) {
        model.dropIndex = nil
        model.dropOnItem = nil
    }

    private func target(_ info: DropInfo) -> (insert: Int, onItem: Int?) {
        let p = CGPoint(x: info.location.x, y: info.location.y + scrollOffset)
        let t = metrics.dropIndex(at: p, pageStart: pageStart, itemCount: items.count)
        // Only app tiles take files dropped onto them, and only from outside.
        if let on = t.onItem, on < items.count, items[on].kind == .app, !isInternal { return t }
        return (t.insert, nil)
    }

    private func update(_ info: DropInfo) {
        let t = target(info)
        if model.dropIndex != t.insert { model.dropIndex = t.insert }
        if model.dropOnItem != t.onItem { model.dropOnItem = t.onItem }
    }

    func performDrop(info: DropInfo) -> Bool {
        let t = target(info)
        model.dropIndex = nil
        model.dropOnItem = nil
        let providers = info.itemProviders(for: [.fileURL, .url])
        guard !providers.isEmpty else { return false }
        let group = group, model = model, items = items
        let draggedURL = model.dragging
        Task { @MainActor in
            var urls: [URL] = []
            for p in providers {
                if let url = await Self.loadURL(p) { urls.append(url) }
            }
            guard !urls.isEmpty else { return }
            let store = LibraryStore.shared
            // Reorder inside the popup.
            if let dragged = draggedURL, let item = items.first(where: { $0.url == dragged || ($0.kind == .app && ItemOpener.appURL(for: $0) == urls.first) }) {
                store.reorderItem(item.id, in: group.id, toShownIndex: t.insert, shown: items)
                return
            }
            // Files dropped on an app tile open with that app.
            if let on = t.onItem, on < items.count, items[on].kind == .app, !urls.contains(where: { $0.pathExtension == "app" }) {
                model.actions.willLaunch()
                ItemOpener.open(urls, withApp: ItemOpener.appURL(for: items[on]))
                model.actions.didLaunch()
                return
            }
            guard model.isEditable(in: group) else { return }
            store.insertItems(urls, into: group.id, atShownIndex: t.insert, shown: items)
        }
        return true
    }

    /// File URL first, then any URL (links from browsers).
    private static func loadURL(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { cont in
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in cont.resume(returning: url) }
            } else if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in cont.resume(returning: url) }
            } else {
                cont.resume(returning: nil)
            }
        }
    }
}
