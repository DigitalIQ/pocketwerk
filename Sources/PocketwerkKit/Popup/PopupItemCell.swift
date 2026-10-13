import AppKit
import SwiftUI

/// What a cell shows: a group item, or the "Open in Finder" cell at the end of a folder.
enum PopupCellContent: Identifiable {
    case item(DockItem)
    case openInFinder(URL)

    var id: String {
        switch self {
        case .item(let i): return i.url.absoluteString
        case .openInFinder(let u): return "finder:" + u.absoluteString
        }
    }
}

/// One cell in grid, list or tiles layout.
struct PopupItemCell: View {
    let content: PopupCellContent
    let index: Int
    let group: ItemGroup
    let style: GroupStyle
    let metrics: PopupMetrics
    let model: PopupModel
    let preview: Bool
    let lightText: Bool
    /// 1...9 when the digit key opens this item.
    var shortcut: Int?

    static let finder = DockItem(kind: .app, url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var localHover = false

    private var url: URL {
        switch content {
        case .item(let i): return i.url
        case .openInFinder(let u): return u
        }
    }

    private var item: DockItem? {
        if case .item(let i) = content { return i }
        return nil
    }

    private var name: String {
        switch content {
        case .item(let i): return PopupIconCache.shared.name(for: i)
        case .openInFinder: return String(localized: "Open in Finder")
        }
    }

    private var isHovered: Bool { preview ? localHover : model.hovered == url }
    /// Keyboard focus: the selection while the keyboard drives it.
    private var isFocused: Bool { model.selection == index && model.focusVisible }
    private var isMissing: Bool { item.map(MissingItemActions.isMissing) ?? false }

    var body: some View {
        let selected = model.selection == index
        let picked = model.picked.contains(url)
        let pressed = model.pressed == url
        let running = style.runningIndicator && (item.map { RunningApps.shared.isRunning($0) } ?? false)
        let radius = cellRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        cellBody(running: running)
            .frame(width: metrics.cell.width, height: metrics.cell.height)
            .background(highlight(radius: radius, picked: picked))
            .overlay {
                if isFocused {
                    // Focus ring in the system accent color, just outside the cell.
                    RoundedRectangle(cornerRadius: radius + 3, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.85), lineWidth: contrast == .increased ? 4 : 3)
                        .padding(-3)
                }
                if model.dropOnItem == index {
                    shape.strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                }
            }
            .overlay(alignment: .topLeading) {
                if let shortcut, model.modifiers.contains(.control) {
                    Text("\(shortcut)")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Circle().fill(Color.accentColor))
                        .padding(3)
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .topTrailing) {
                if picked {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                        .font(.system(size: max(12, metrics.iconSize * 0.24)))
                        .padding(2)
                }
            }
            .scaleEffect(reduceMotion ? 1 : (pressed ? 0.95 : (isHovered && style.hover == .heavy ? 1.04 : 1)))
            .brightness(pressed ? -0.15 : 0)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .contentShape(shape)
            .overlay { if !preview { hitArea } }
            .onHover { if preview { localHover = $0 } }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityName(running: running))
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(selected || picked ? .isSelected : [])
            .accessibilityHint(accessibilityHint)
            .accessibilityAction { if !preview { click([]) } }
            .accessibilityAction(named: Text("Quick Look")) { if let item { model.actions.quickLook(item) } }
    }

    private var cellRadius: CGFloat {
        switch style.layout {
        case .grid: return min(16, metrics.cell.width * 0.18)
        case .list: return 8
        case .tiles: return 14
        }
    }

    @ViewBuilder
    private func highlight(radius: CGFloat, picked: Bool) -> some View {
        let base = style.highlightColor.color
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if picked {
            shape.fill(Color.accentColor.opacity(0.22))
        } else if (isHovered || isFocused) && style.hover != .none {
            shape.fill(base.opacity(style.hover == .heavy ? 1 : 0.6))
        } else if style.layout == .tiles {
            shape.fill(base.opacity(0.35))
        } else {
            Color.clear
        }
    }

    // MARK: Layouts

    @ViewBuilder
    private func cellBody(running: Bool) -> some View {
        switch style.layout {
        case .grid:
            VStack(spacing: 2) {
                iconView
                    .overlay(alignment: .bottom) { runningDot(running).offset(y: 5) }
                    .padding(.top, 4)
                if metrics.labelHeight > 0 {
                    label(lines: metrics.labelLines)
                        .frame(width: metrics.cell.width - 4, height: metrics.labelHeight, alignment: .top)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
        case .list:
            HStack(spacing: 8) {
                iconView
                label(lines: 1)
                Spacer(minLength: 0)
                runningDot(running)
            }
            .padding(.horizontal, 8)
        case .tiles:
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    iconView
                    Spacer(minLength: 0)
                    runningDot(running).padding(.top, 4)
                }
                Spacer(minLength: 4)
                if metrics.labelHeight > 0 {
                    label(lines: 2).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        let size = metrics.iconSize
        ZStack {
            if let plate = style.iconPlate {
                RoundedRectangle(cornerRadius: size * 0.24).fill(plate.color).frame(width: size * 1.1, height: size * 1.1)
            }
            Image(nsImage: image(size: size))
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .saturation(isMissing ? 0 : 1)
                .opacity(isMissing ? 0.45 : 1)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if isMissing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.black, .yellow)
                    .font(.system(size: max(11, size * 0.26)))
                    .offset(x: 3, y: 3)
                    .help("Can’t be found. Click to locate or remove it.")
            }
        }
    }

    private func image(size: CGFloat) -> NSImage {
        _ = PopupIconCache.shared.generation
        switch content {
        case .item(let i): return PopupIconCache.shared.icon(for: i, size: size)
        case .openInFinder: return PopupIconCache.shared.icon(for: Self.finder, size: size)
        }
    }

    @ViewBuilder
    private func runningDot(_ running: Bool) -> some View {
        Circle()
            .fill(lightText ? Color.white.opacity(0.85) : Color.black.opacity(0.7))
            .frame(width: 4, height: 4)
            .opacity(running ? 1 : 0)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func label(lines: Int) -> some View {
        let l = style.labels
        let visible = l.mode == .always || (l.mode == .onHover && (isHovered || isFocused))
        if model.renaming == url, let item {
            RenameField(item: item, group: group, model: model, font: PopupLook.font(l, size: metrics.labelSize))
        } else {
            Text(name)
                .font(PopupLook.font(l, size: metrics.labelSize))
                .foregroundStyle(PopupLook.labelColor(l, lightText: lightText))
                .lineLimit(lines)
                .multilineTextAlignment(style.layout == .grid ? .center : .leading)
                .truncationMode(item?.kind == .file ? .middle : .tail)
                .shadow(color: l.shadow ? (lightText ? .black.opacity(0.45) : .white.opacity(0.35)) : .clear, radius: 1.5, y: 0.5)
                .padding(.horizontal, l.backdrop ? 5 : 0)
                .background {
                    if l.backdrop {
                        Capsule().fill(Color.black.opacity(lightText ? 0.28 : 0.1))
                    }
                }
                .opacity(visible ? 1 : 0)
                .padding(.horizontal, style.layout == .grid ? 2 : 0)
        }
    }

    private func accessibilityName(running: Bool) -> String {
        guard let item else { return name }
        var parts = [name]
        switch item.kind {
        case .app: parts.append(running ? String(localized: "App, running") : String(localized: "App"))
        case .file: parts.append(String(localized: "File"))
        case .folder: parts.append(String(localized: "Folder"))
        case .link: parts.append(String(localized: "Link"))
        }
        if isMissing { parts.append(String(localized: "missing")) }
        if model.picked.contains(item.url) { parts.append(String(localized: "selected")) }
        return parts.joined(separator: ", ")
    }

    private var accessibilityHint: Text {
        if isMissing { return Text("Locate or remove the missing item") }
        if item?.kind == .folder { return Text("Shows the folder contents") }
        if let shortcut { return Text("Shortcut: \(shortcut)") }
        return Text("")
    }

    // MARK: Interaction

    private func click(_ modifiers: NSEvent.ModifierFlags) {
        model.selection = index
        model.focusVisible = false
        switch content {
        case .item(let i):
            if MissingItemActions.isMissing(i), !modifiers.contains(.command) {
                MissingItemActions.menu(for: i, group: group, model: model).popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
                return
            }
            model.activate(i, in: group, modifiers: modifiers)
        case .openInFinder(let folder):
            model.actions.willLaunch()
            NSWorkspace.shared.open(folder)
            model.actions.didLaunch()
        }
    }

    private var hitArea: some View {
        let editable = model.isEditable(in: group)
        return ItemHitArea(
            onHover: { inside in
                if inside { model.hovered = url } else if model.hovered == url { model.hovered = nil }
            },
            onPress: { down in
                if down { model.pressed = url } else if model.pressed == url { model.pressed = nil }
            },
            onClick: { click($0) },
            menu: {
                guard let item else { return nil }
                return ItemMenu.menu(for: item, group: group, model: model)
            },
            dragPayload: {
                guard let item else { return nil }
                let target = item.kind == .app ? ItemOpener.appURL(for: item) : item.url
                return (target, PopupIconCache.shared.icon(for: item, size: metrics.iconSize))
            },
            onDragStart: { model.dragging = url },
            onDragEnd: { point, operation, outside in
                let dragged = model.dragging
                model.dragging = nil
                model.dropIndex = nil
                model.dropOnItem = nil
                // Dropped nowhere outside the popup: remove the item ("poof").
                if outside, operation.isEmpty, editable, let item, dragged == url {
                    LibraryStore.shared.removeItem(item.id, from: LibraryStore.shared.owningGroupID(of: item.id, fallback: group.id))
                    PoofEffect.show(at: point)
                    PopupSound.play(.remove)
                }
            },
            removableByDragOut: editable && item != nil
        )
    }
}

/// Inline rename inside a cell.
private struct RenameField: View {
    let item: DockItem
    let group: ItemGroup
    let model: PopupModel
    let font: Font
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Name", text: $text)
            .textFieldStyle(.roundedBorder)
            .font(font)
            .focused($focused)
            .onAppear {
                text = item.displayName
                focused = true
            }
            .onSubmit {
                LibraryStore.shared.renameItem(item.id, in: group.id, to: text)
                model.renaming = nil
            }
            .onExitCommand { model.renaming = nil }
    }
}
