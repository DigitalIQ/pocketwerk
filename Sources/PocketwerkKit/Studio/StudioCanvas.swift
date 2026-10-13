import SwiftUI

/// Large live preview: the popup over a chosen backdrop and the Dock icon on a small Dock shelf.
struct StudioCanvas: View {
    @Bindable var editor: StudioEditor
    let onSaveTheme: () -> Void
    @State private var popupSize: CGSize = .zero

    private var scheme: ColorScheme? {
        switch editor.style.appearance {
        case .light: return .light
        case .dark: return .dark
        case .system:
            switch editor.previewScheme {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    var body: some View {
        let group = editor.group
        GeometryReader { geo in
            ZStack {
                PreviewBackdrop(choice: editor.wallpaper)
                VStack(spacing: 0) {
                    toolbar
                    Spacer(minLength: 16)
                    popup(group: group, available: CGSize(width: geo.size.width - 48, height: geo.size.height - 230))
                    Spacer(minLength: 16)
                    DockShelf(group: group)
                        .padding(.bottom, 22)
                }
            }
            .environment(\.colorScheme, scheme ?? .dark)
        }
        .clipped()
    }

    private func popup(group: ItemGroup, available: CGSize) -> some View {
        let scale = popupSize.width > 0 && popupSize.height > 0
            ? max(0.3, min(1, available.width / popupSize.width, available.height / popupSize.height)) : 1
        return PopupGroupView(group: group, preview: true)
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { popupSize = $0 }
            .scaleEffect(scale)
            .frame(width: popupSize.width * scale, height: popupSize.height * scale)
            .animation(.smooth(duration: 0.25), value: group.style)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Popup Preview"))
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Menu {
                Picker("Backdrop", selection: $editor.wallpaper) {
                    ForEach(PreviewWallpaper.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Backdrop", systemImage: "photo.on.rectangle")
            }
            .menuStyle(.button)
            .fixedSize()
            .help(Text("Preview Backdrop"))

            Picker("Preview Appearance", selection: $editor.previewScheme) {
                Image(systemName: "circle.lefthalf.filled").accessibilityLabel(Text("System")).tag(PreviewScheme.system)
                Image(systemName: "sun.max").accessibilityLabel(Text("Light")).tag(PreviewScheme.light)
                Image(systemName: "moon").accessibilityLabel(Text("Dark")).tag(PreviewScheme.dark)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .disabled(editor.style.appearance != .system)
            .help(Text("Preview Appearance"))

            Spacer()

            Button {
                withAnimation(.smooth) { editor.randomize() }
            } label: {
                Label("Randomize", systemImage: "dice")
            }
            .help(Text("Try a random look"))
            Button {
                withAnimation(.smooth) { editor.reset() }
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .help(Text("Back to the default look"))
            Button(action: onSaveTheme) {
                Label("Save as Theme", systemImage: "plus.square.on.square")
            }
            .help(Text("Save this look as a theme"))
        }
        .buttonStyle(.glass)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }
}

/// The canvas backdrop: a soft mesh, or the real desktop picture.
struct PreviewBackdrop: View {
    let choice: PreviewWallpaper

    var body: some View {
        switch choice {
        case .desktop: WallpaperFill(blur: 0, dim: 0, aligned: false)
        default: MeshFill(colors: choice.colors)
        }
    }
}

/// A Dock-like shelf with two neighbor apps and the group's live Dock icon.
struct DockShelf: View {
    let group: ItemGroup
    @State private var hovering = false
    @State private var iconVersion = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let neighbors: [DockItem] = ["/System/Library/CoreServices/Finder.app", "/System/Applications/System Settings.app"]
        .map { DockItem(kind: .app, url: URL(fileURLWithPath: $0)) }

    var body: some View {
        let _ = iconVersion
        let icon = IconRenderer.groupIcon(group, size: 64)
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(Self.neighbors) { item in
                Image(nsImage: IconRenderer.icon(for: item, size: 52))
                    .resizable()
                    .frame(width: 52, height: 52)
                    .opacity(0.55)
                    .accessibilityHidden(true)
            }
            VStack(spacing: 3) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .scaleEffect(hovering && !reduceMotion ? 1.12 : 1, anchor: .bottom)
                    .animation(.snappy(duration: 0.2), value: hovering)
                    .onHover { hovering = $0 }
                Circle().fill(.primary.opacity(0.7)).frame(width: 4, height: 4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Dock Icon Preview"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onReceive(NotificationCenter.default.publisher(for: .itemIconsDidChange)) { _ in iconVersion += 1 }
    }
}
