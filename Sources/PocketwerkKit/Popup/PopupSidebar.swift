import SwiftUI
import UniformTypeIdentifiers

/// Group list on the left side of the popup (navigation "sidebar").
/// Full rows with name and ⌘-digit badge, or a compact icon rail. Rows take drops for their group.
struct PopupSidebar: View {
    let model: PopupModel
    let style: GroupStyle
    let lightText: Bool

    static let fullWidth: CGFloat = 188
    static let compactWidth: CGFloat = 56
    static let rowHeight: CGFloat = 30

    static func minHeight(groupCount: Int) -> CGFloat {
        12 + CGFloat(groupCount) * (rowHeight + 2) + 40
    }

    private var collapsed: Bool { model.store.settings.sidebarCollapsed }
    private var color: Color { PopupLook.labelColor(style.labels, lightText: lightText) }

    private var rows: some View {
        VStack(spacing: 2) {
            ForEach(Array(model.groups.enumerated()), id: \.element.id) { i, group in
                SidebarRow(group: group, index: i, model: model, collapsed: collapsed, color: color, labels: style.labels)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Scrolls only when the groups do not fit.
            ViewThatFits(in: .vertical) {
                rows
                ScrollView(.vertical) { rows }.scrollIndicators(.never)
            }
            Spacer(minLength: 0)
            HStack {
                Button { model.toggleSidebar() } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(collapsed ? "Show group names" : "Show icons only")
                .accessibilityLabel(collapsed ? Text("Show group names") : Text("Show icons only"))
                if !collapsed { Spacer() }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            .foregroundStyle(color.opacity(0.7))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Groups")
    }
}

private struct SidebarRow: View {
    let group: ItemGroup
    let index: Int
    let model: PopupModel
    let collapsed: Bool
    let color: Color
    let labels: LabelStyle

    @State private var hovered = false
    @State private var targeted = false

    private var selected: Bool { model.position.group == index }

    var body: some View {
        Button {
            model.showGroup(at: index)
        } label: {
            HStack(spacing: 8) {
                marker
                if !collapsed {
                    Text(group.name)
                        .font(PopupLook.font(labels, size: 13, weightBoost: selected ? 0.15 : 0))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    if index < 9 {
                        Text("⌘\(index + 1)")
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(color.opacity(0.1)))
                            .opacity(0.75)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.horizontal, collapsed ? 0 : 8)
            .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
            .frame(height: PopupSidebar.rowHeight)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? color.opacity(0.18) : (hovered || targeted ? color.opacity(0.09) : .clear))
            )
            .overlay {
                if targeted {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
            // The whole row is the hit target.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
        .onHover { hovered = $0 }
        .help(collapsed ? group.name : "")
        .onDrop(of: [.fileURL, .url], isTargeted: $targeted) { providers in
            guard group.smart == nil else { return false }
            PopupDrops.load(providers) { urls in
                LibraryStore.shared.insertURLs(urls, into: group.id)
            }
            return true
        }
        .accessibilityLabel(Text(group.name))
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
        .accessibilityHint(index < 9 ? Text("Command \(index + 1)") : Text(""))
    }

    @ViewBuilder
    private var marker: some View {
        if let emoji = group.emoji, !emoji.isEmpty {
            Text(emoji).font(.system(size: collapsed ? 18 : 15)).frame(width: 22)
        } else if let first = model.store.visibleItems(of: group).first {
            // The first item's icon reads better than a color dot on any background.
            let size: CGFloat = collapsed ? 24 : 18
            Image(nsImage: PopupIconCache.shared.icon(for: first, size: size))
                .resizable()
                .frame(width: size, height: size)
                .frame(width: 22)
        } else {
            Circle()
                .fill(GroupColor.swatch(for: group).color)
                .frame(width: collapsed ? 14 : 10, height: collapsed ? 14 : 10)
                .overlay(Circle().strokeBorder(color.opacity(0.25), lineWidth: 0.5))
                .frame(width: 22)
        }
    }
}

/// Loading dropped URLs from item providers.
enum PopupDrops {
    /// Loads every URL, then calls back on the main actor with all of them.
    static func load(_ providers: [NSItemProvider], then done: @escaping @MainActor ([URL]) -> Void) {
        Task { @MainActor in
            var urls: [URL] = []
            for p in providers {
                if let url = await loadURL(p) { urls.append(url) }
            }
            if !urls.isEmpty { done(urls) }
        }
    }

    /// File URL first, then any URL (links from browsers).
    static func loadURL(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { cont in
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) || provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in cont.resume(returning: url) }
            } else {
                cont.resume(returning: nil)
            }
        }
    }
}
