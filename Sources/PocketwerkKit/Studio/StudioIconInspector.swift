import SwiftUI

/// What the Dock icon shows. Folder is the item grid on a folder shape.
enum IconMode: String, CaseIterable, Identifiable {
    case grid, stack, folder, symbol, emoji, text, monogram, image
    var id: String { rawValue }

    var title: String {
        switch self {
        case .grid: String(localized: "Grid")
        case .stack: String(localized: "Stack")
        case .folder: String(localized: "Folder")
        case .symbol: String(localized: "Symbol")
        case .emoji: String(localized: "Emoji")
        case .text: String(localized: "Text")
        case .monogram: String(localized: "Monogram")
        case .image: String(localized: "Image")
        }
    }

    static func of(_ spec: IconSpec) -> IconMode {
        switch spec.content {
        case .itemGrid: spec.shape == .folder ? .folder : .grid
        case .itemStack: .stack
        case .symbol: .symbol
        case .emoji: .emoji
        case .text: .text
        case .monogram: .monogram
        case .image: .image
        }
    }

    /// The spec with this mode, keeping what can be kept. Image needs a path and returns nil without one.
    func applied(to spec: IconSpec, name: String, imagePath: String? = nil) -> IconSpec? {
        var s = spec
        let gridCount: Int = if case .itemGrid(let c) = spec.content { c } else { 0 }
        if s.shape == .folder && self != .folder { s.shape = .squircle }
        switch self {
        case .grid: s.content = .itemGrid(count: gridCount)
        case .stack: s.content = .itemStack
        case .folder:
            s.content = .itemGrid(count: gridCount)
            s.shape = .folder
        case .symbol:
            if case .symbol = spec.content {} else { s.content = .symbol(name: IconPacks.pack(id: spec.pack).symbols[0]) }
        case .emoji:
            if case .emoji = spec.content {} else { s.content = .emoji("⭐️") }
        case .text:
            if case .text = spec.content {} else { s.content = .text(String(name.prefix(4))) }
        case .monogram: s.content = .monogram
        case .image:
            if let imagePath { s.content = .image(path: imagePath) } else if case .image = spec.content {} else { return nil }
        }
        return s
    }
}

struct StudioIconInspector: View {
    let editor: StudioEditor

    var body: some View {
        let spec = editor.icon
        let mode = IconMode.of(spec)
        Form {
            Section("Style") { IconModeGrid(editor: editor) }
            IconContentOptions(editor: editor, mode: mode)
            if mode != .folder {
                Section("Shape") { ShapeRow(editor: editor) }
            }
            IconColorSection(editor: editor)
            Section("Finish") {
                StudioSlider(title: "Opacity", value: editor.binding(\.icon.opacity), range: 0.1...1, editor: editor)
                StudioSlider(title: "Matte", value: editor.binding(\.icon.matte), range: 0...1, editor: editor)
                Toggle("Glossy", isOn: editor.binding(\.icon.glossy))
                Toggle("Lift", isOn: editor.binding(\.icon.lift))
            }
            Section("Border") {
                BorderEditor(border: editor.binding(\.icon.border), editor: editor)
            }
        }
        .formStyle(.grouped)
    }
}

/// Eight live previews of the group's icon, one per mode.
private struct IconModeGrid: View {
    let editor: StudioEditor

    var body: some View {
        let group = editor.group
        let current = IconMode.of(group.icon)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
            ForEach(IconMode.allCases) { mode in
                PickTile(title: mode.title, selected: mode == current, action: { pick(mode) }) {
                    preview(mode, group: group)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func preview(_ mode: IconMode, group: ItemGroup) -> some View {
        var spec = mode.applied(to: group.icon, name: group.name) ?? group.icon
        if mode == .image, case .image = group.icon.content {} else if mode == .image {
            spec.content = .symbol(name: "photo")
        }
        let image = IconRenderer.render(spec: spec, style: group.style, name: group.name, items: group.sortedItems, size: 52)
        return Image(nsImage: image)
            .resizable()
            .frame(width: 52, height: 52)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }

    private func pick(_ mode: IconMode) {
        let group = editor.group
        if mode == .image, case .image = group.icon.content {} else if mode == .image {
            guard let path = StudioEditor.importImage(), let spec = mode.applied(to: group.icon, name: group.name, imagePath: path) else { return }
            editor.edit { $0.icon = spec }
            return
        }
        guard let spec = mode.applied(to: group.icon, name: group.name) else { return }
        editor.edit { $0.icon = spec }
    }
}

/// Options of the chosen mode.
private struct IconContentOptions: View {
    let editor: StudioEditor
    let mode: IconMode

    var body: some View {
        switch mode {
        case .grid, .folder:
            Section("Grid") {
                Picker("Items", selection: gridCount) {
                    Text("Auto").tag(0)
                    Text("2×2").tag(4)
                    Text("3×3").tag(9)
                    Text("4×4").tag(16)
                }
                .pickerStyle(.segmented)
                Toggle("Dense", isOn: editor.binding(\.icon.dense))
                Toggle("Round Items", isOn: editor.binding(\.icon.roundItems))
            }
        case .stack:
            StackOptionsSection(editor: editor)
        case .symbol:
            SymbolPackSection(editor: editor)
        case .emoji:
            Section("Emoji") {
                TextField("Emoji", text: textContent)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                    ForEach(["⭐️", "🚀", "🎧", "🎨", "💼", "📚", "🧪", "🛠️", "🎮", "🍕", "🌿", "❤️", "📷", "✈️", "🧠", "💬"], id: \.self) { e in
                        Button(e) { editor.edit { $0.icon.content = .emoji(e) } }
                            .buttonStyle(.plain)
                            .font(.title2)
                            .accessibilityLabel(Text(e))
                    }
                }
            }
        case .text:
            Section("Text") {
                TextField("Text", text: textContent)
            }
        case .monogram:
            Section("Monogram") {
                LabeledContent("Letters", value: IconPainter.monogram(editor.group.name))
            }
        case .image:
            Section("Image") {
                if case .image(let path) = editor.icon.content {
                    LabeledContent("File", value: URL(fileURLWithPath: path).lastPathComponent)
                }
                Button("Choose Image…") {
                    if let path = StudioEditor.importImage() { editor.edit { $0.icon.content = .image(path: path) } }
                }
            }
        }
    }

    private var gridCount: Binding<Int> {
        Binding(get: {
            if case .itemGrid(let c) = editor.icon.content { return c } else { return 0 }
        }, set: { c in editor.edit { $0.icon.content = .itemGrid(count: c) } })
    }

    /// Text of emoji and text content.
    private var textContent: Binding<String> {
        Binding(get: {
            switch editor.icon.content {
            case .emoji(let s), .text(let s): return s
            default: return ""
            }
        }, set: { s in
            editor.edit { g in
                if case .emoji = g.icon.content { g.icon.content = .emoji(String(s.prefix(2))) } else { g.icon.content = .text(String(s.prefix(8))) }
            }
        })
    }
}

private struct StackOptionsSection: View {
    let editor: StudioEditor

    var body: some View {
        Section("Stack") {
            Picker("Direction", selection: editor.binding(\.icon.stack.direction)) {
                Image(systemName: "arrow.down.right").accessibilityLabel(Text("Down Right")).tag(StackDirection.downRight)
                Image(systemName: "arrow.down").accessibilityLabel(Text("Down")).tag(StackDirection.down)
                Image(systemName: "arrow.down.left").accessibilityLabel(Text("Down Left")).tag(StackDirection.downLeft)
            }
            .pickerStyle(.segmented)
            Picker("Depth", selection: editor.binding(\.icon.stack.depth)) {
                Text("2").tag(2)
                Text("3").tag(3)
                Text("4").tag(4)
            }
            .pickerStyle(.segmented)
            Toggle("Depth Fade", isOn: editor.binding(\.icon.stack.fade))
            Toggle("Depth Blur", isOn: editor.binding(\.icon.stack.blur))
            StudioSlider(title: "Icon Scale", value: editor.binding(\.icon.stack.scale), range: 0.4...1, editor: editor)
            StudioSlider(title: "Spacing", value: editor.binding(\.icon.stack.spacing), range: 0.02...0.3, editor: editor)
            Toggle("Shuffle Apps", isOn: editor.binding(\.icon.stack.shuffle))
        }
    }
}

private struct SymbolPackSection: View {
    let editor: StudioEditor

    var body: some View {
        let pack = IconPacks.pack(id: editor.icon.pack)
        let current: String = if case .symbol(let n) = editor.icon.content { n } else { "" }
        Section("Icon Pack") {
            Picker("Pack", selection: Binding(get: { pack.id }, set: { id in editor.edit { $0.icon.pack = id } })) {
                ForEach(IconPacks.all) { Text(LocalizedStringKey($0.name)).tag($0.id) }
            }
            .pickerStyle(.segmented)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 6) {
                ForEach(pack.symbols, id: \.self) { symbol in
                    Button {
                        editor.edit { $0.icon.content = .symbol(name: symbol) }
                    } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 17))
                            .symbolRenderingMode(pack.finish == .multicolor ? .multicolor : .hierarchical)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(RoundedRectangle(cornerRadius: 7).fill(symbol == current ? Color.accentColor.opacity(0.25) : .clear))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(symbol.replacingOccurrences(of: ".", with: " ")))
                    .accessibilityAddTraits(symbol == current ? .isSelected : [])
                }
            }
        }
    }
}

private struct ShapeRow: View {
    let editor: StudioEditor

    var body: some View {
        let current = editor.icon.shape
        HStack(spacing: 6) {
            ForEach([IconShape.squircle, .roundedSquare, .circle, .square, .none], id: \.self) { shape in
                Button {
                    editor.edit { $0.icon.shape = shape }
                } label: {
                    IconShapeGlyph(shape: shape, size: 20)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(RoundedRectangle(cornerRadius: 8).fill(shape == current ? Color.accentColor.opacity(0.22) : .primary.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .help(Text(IconShapeGlyph.title(shape)))
                .accessibilityLabel(Text(IconShapeGlyph.title(shape)))
                .accessibilityAddTraits(shape == current ? .isSelected : [])
            }
        }
    }
}

/// Match the popup look, or an own color, gradient, glass or texture.
private struct IconColorSection: View {
    let editor: StudioEditor

    enum Kind: String, CaseIterable, Identifiable {
        case color, gradient, glass, texture
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .color: "Color"
            case .gradient: "Gradient"
            case .glass: "Glass"
            case .texture: "Texture"
            }
        }
    }

    var body: some View {
        let own = editor.icon.background
        Section("Color") {
            Toggle("Match Theme", isOn: matchTheme)
            if let own {
                Picker("Fill", selection: kind) {
                    ForEach(Kind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                switch own {
                case .gradient:
                    ColorRow(title: "Start", color: gradientColor(0))
                    ColorRow(title: "End", color: gradientColor(1))
                case .texture:
                    Picker("Texture", selection: textureName) {
                        ForEach(TextureKind.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
                    }
                    ColorRow(title: "Tint", color: primary)
                default:
                    SwatchPicker(title: "Color", color: primary)
                }
            }
            if showsForeground {
                SwatchPicker(title: "Symbol Color", color: editor.binding(\.icon.foreground))
            }
        }
    }

    private var showsForeground: Bool {
        switch editor.icon.content {
        case .symbol, .text, .monogram: true
        default: false
        }
    }

    private var matchTheme: Binding<Bool> {
        Binding(get: { editor.icon.background == nil }, set: { on in
            editor.edit { g in g.icon.background = on ? nil : .solid(g.style.background.representativeColor) }
        })
    }

    private var kind: Binding<Kind> {
        Binding(get: {
            switch editor.icon.background {
            case .gradient: .gradient
            case .glass: .glass
            case .texture: .texture
            default: .color
            }
        }, set: { k in
            editor.edit { g in
                let c = g.icon.background?.representativeColor ?? g.style.background.representativeColor
                switch k {
                case .color: g.icon.background = .solid(c)
                case .gradient: g.icon.background = .gradient(colors: [c.lighter(0.2), c.darker(0.3)], angle: 90)
                case .glass: g.icon.background = .glass(tint: c.alpha(0.35), intensity: 1)
                case .texture: g.icon.background = .texture(name: TextureKind.knit.rawValue, tint: TextureKind.knit.suggestedTint)
                }
            }
        })
    }

    /// The main color of the own fill.
    private var primary: Binding<RGBA> {
        Binding(get: {
            switch editor.icon.background {
            case .solid(let c): c
            case .glass(let t, _): t
            case .texture(_, let t): t
            default: editor.icon.background?.representativeColor ?? .white
            }
        }, set: { c in
            editor.edit { g in
                switch g.icon.background {
                case .glass(let t, let i): g.icon.background = .glass(tint: c.alpha(t.a), intensity: i)
                case .texture(let n, _): g.icon.background = .texture(name: n, tint: c)
                default: g.icon.background = .solid(c.opaque)
                }
            }
        })
    }

    private var textureName: Binding<String> {
        Binding(get: {
            if case .texture(let n, _) = editor.icon.background { n } else { TextureKind.knit.rawValue }
        }, set: { n in
            editor.edit { $0.icon.background = .texture(name: n, tint: TextureKind(name: n).suggestedTint) }
        })
    }

    private func gradientColor(_ i: Int) -> Binding<RGBA> {
        Binding(get: {
            if case .gradient(let colors, _) = editor.icon.background { colors[safe: i] ?? .white } else { .white }
        }, set: { c in
            editor.edit { g in
                guard case .gradient(var colors, let angle) = g.icon.background, colors.indices.contains(i) else { return }
                colors[i] = c
                g.icon.background = .gradient(colors: colors, angle: angle)
            }
        })
    }
}
