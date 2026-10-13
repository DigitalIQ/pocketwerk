import SwiftUI

/// Fill types offered in the inspector.
enum FillKind: String, CaseIterable, Identifiable {
    case glass, color, gradient, mesh, texture, effect, photo, wallpaper
    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass: String(localized: "Glass")
        case .color: String(localized: "Color")
        case .gradient: String(localized: "Gradient")
        case .mesh: String(localized: "Mesh")
        case .texture: String(localized: "Texture")
        case .effect: String(localized: "Living Effect")
        case .photo: String(localized: "Photo")
        case .wallpaper: String(localized: "Desktop Picture")
        }
    }

    var symbol: String {
        switch self {
        case .glass: "drop"
        case .color: "circle.fill"
        case .gradient: "circle.lefthalf.filled"
        case .mesh: "circle.hexagongrid.fill"
        case .texture: "square.grid.3x3.square"
        case .effect: "sparkles"
        case .photo: "photo"
        case .wallpaper: "menubar.dock.rectangle"
        }
    }

    static func of(_ bg: Background) -> FillKind {
        switch bg {
        case .glass: .glass
        case .solid: .color
        case .gradient: .gradient
        case .mesh: .mesh
        case .texture: .texture
        case .fx: .effect
        case .image: .photo
        case .wallpaper: .wallpaper
        }
    }

    /// A fill of this kind that keeps the colors of the current one where possible.
    /// Photo returns nil: it needs a file.
    func makeDefault(from current: Background) -> Background? {
        let base = current.representativeColor
        let colors = current.paletteColors.count >= 2 ? current.paletteColors : [base.lighter(0.15), base.darker(0.35)]
        switch self {
        case .glass: return .glass(tint: base.alpha(0.3), intensity: 1)
        case .color: return .solid(base)
        case .gradient: return .gradient(colors: Array(colors.prefix(2)), angle: 45)
        case .mesh: return .mesh(colors: colors.count >= 3 ? Array(colors.prefix(4)) : colors + [base.darker(0.5)])
        case .texture: return .texture(name: TextureKind.linen.rawValue, tint: TextureKind.linen.suggestedTint)
        case .effect: return .fx(FXKind.aurora.defaultParams)
        case .photo: return nil
        case .wallpaper: return .wallpaper(blur: 30, dim: 0.1)
        }
    }
}

extension FXKind {
    var title: String {
        switch self {
        case .arcs: String(localized: "Ribbons")
        case .curtains: String(localized: "Curtains")
        case .waves: String(localized: "Waves")
        case .marble: String(localized: "Marble")
        case .snow: String(localized: "Snow")
        case .embers: String(localized: "Embers")
        case .glyphRain: String(localized: "Glyph Rain")
        case .blobs: String(localized: "Blobs")
        case .fur: String(localized: "Fur")
        case .rain: String(localized: "Rain")
        case .fog: String(localized: "Fog")
        case .driftingLight: String(localized: "Drifting Light")
        case .lava: String(localized: "Lava")
        case .aurora: String(localized: "Aurora")
        case .starfield: String(localized: "Starfield")
        case .plasma: String(localized: "Plasma")
        case .bubbles: String(localized: "Bubbles")
        case .ripples: String(localized: "Ripples")
        }
    }

    /// Parameters of the first built-in look with this effect, so a new effect starts out looking good.
    var defaultParams: FXParams {
        for theme in ThemeLibrary.builtIn {
            if case .fx(let p) = theme.style.background, p.kind == self { return p }
        }
        return FXParams(kind: self, palette: [RGBA(0.1, 0.1, 0.2), RGBA(0.4, 0.7, 1), RGBA(1, 0.5, 0.7)])
    }

    /// Name of the p3 knob for this effect.
    var sizeKnob: LocalizedStringKey {
        switch self {
        case .snow, .rain, .embers, .bubbles, .starfield: "Density"
        case .fur: "Hair Length"
        case .waves: "Wave Height"
        case .ripples: "Drops"
        case .fog: "Thickness"
        default: "Size"
        }
    }

    var hasWind: Bool { [.snow, .rain, .fog, .embers, .arcs].contains(self) }
    var hasVariants: Bool { [.arcs, .curtains, .marble, .fur].contains(self) }
}

extension FXPointer {
    var title: LocalizedStringKey {
        switch self {
        case .ripple: "Ripple"
        case .comb: "Comb"
        case .shove: "Push"
        case .still: "None"
        }
    }
}

struct StudioPopupInspector: View {
    let editor: StudioEditor

    var body: some View {
        Form {
            FillSection(editor: editor)
            Section("Glass and Finish") {
                StudioSlider(title: "Glass Effect", value: editor.binding(\.style.glassAmount), range: 0...1, editor: editor)
                StudioSlider(title: "Opacity", value: editor.binding(\.style.opacity), range: 0.1...1, editor: editor)
                StudioSlider(title: "Matte", value: editor.binding(\.style.matte), range: 0...1, editor: editor)
                Toggle("Popup Follows Dock Icon", isOn: editor.binding(\.style.mirrorIcon))
            }
            Section("Border and Corners") {
                BorderEditor(border: editor.binding(\.style.border), editor: editor)
                StudioSlider(title: "Corner Radius", value: editor.binding(\.style.cornerRadius), range: 0...44, step: 1, format: .points, editor: editor)
                Toggle("Shadow", isOn: editor.binding(\.style.shadow))
            }
            LabelSection(editor: editor)
            Section("Header and Hover") {
                Picker("Header", selection: editor.binding(\.style.header)) {
                    Text("Left").tag(HeaderAlignment.leading)
                    Text("Center").tag(HeaderAlignment.center)
                    Text("Off").tag(HeaderAlignment.hidden)
                }
                .pickerStyle(.segmented)
                Picker("Hover", selection: editor.binding(\.style.hover)) {
                    Text("None").tag(HoverHighlight.none)
                    Text("Subtle").tag(HoverHighlight.subtle)
                    Text("Strong").tag(HoverHighlight.heavy)
                }
                .pickerStyle(.segmented)
                ColorRow(title: "Highlight", color: editor.binding(\.style.highlightColor), supportsOpacity: true)
                Toggle("Icon Plate", isOn: plateOn)
                if editor.style.iconPlate != nil {
                    ColorRow(title: "Plate Color", color: plateColor, supportsOpacity: true)
                }
            }
            Section("Appearance") {
                Picker("Appearance", selection: editor.binding(\.style.appearance)) {
                    Text("System").tag(AppearanceChoice.system)
                    Text("Light").tag(AppearanceChoice.light)
                    Text("Dark").tag(AppearanceChoice.dark)
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }

    private var plateOn: Binding<Bool> {
        Binding(get: { editor.style.iconPlate != nil }, set: { on in
            editor.edit { $0.style.iconPlate = on ? RGBA(1, 1, 1, 0.14) : nil }
        })
    }

    private var plateColor: Binding<RGBA> {
        Binding(get: { editor.style.iconPlate ?? .clear }, set: { c in editor.edit { $0.style.iconPlate = c } })
    }
}

// MARK: - Fill

private struct FillSection: View {
    let editor: StudioEditor

    var body: some View {
        let bg = editor.style.background
        Section("Fill") {
            Picker(selection: kind) {
                ForEach(FillKind.allCases) { k in
                    Label(k.title, systemImage: k.symbol).tag(k)
                }
            } label: { Text("Type") }
            switch bg {
            case .glass: GlassFillEditor(editor: editor)
            case .solid: SwatchPicker(title: "Color", color: solid)
            case .gradient: GradientFillEditor(editor: editor)
            case .mesh: MeshFillEditor(editor: editor)
            case .texture: TextureFillEditor(editor: editor)
            case .fx: EffectFillEditor(editor: editor)
            case .image: PhotoFillEditor(editor: editor)
            case .wallpaper: WallpaperFillEditor(editor: editor)
            }
        }
    }

    private var kind: Binding<FillKind> {
        Binding(get: { FillKind.of(editor.style.background) }, set: { k in
            guard k != FillKind.of(editor.style.background) else { return }
            if k == .photo {
                guard let path = StudioEditor.importImage() else { return }
                editor.edit { $0.style.background = .image(path: path, dim: 0.15, blur: 0) }
            } else if let bg = k.makeDefault(from: editor.style.background) {
                editor.edit { $0.style.background = bg }
            }
        })
    }

    private var solid: Binding<RGBA> {
        Binding(get: {
            if case .solid(let c) = editor.style.background { c } else { .black }
        }, set: { c in editor.edit { $0.style.background = .solid(c) } })
    }
}

private struct GlassFillEditor: View {
    let editor: StudioEditor

    private var tint: Binding<RGBA> {
        Binding(get: {
            if case .glass(let t, _) = editor.style.background { t } else { .clear }
        }, set: { t in
            editor.edit { g in
                if case .glass(_, let i) = g.style.background { g.style.background = .glass(tint: t, intensity: i) }
            }
        })
    }

    private var amount: Binding<Double> {
        Binding(get: { tint.wrappedValue.a }, set: { a in tint.wrappedValue = tint.wrappedValue.alpha(a) })
    }

    var body: some View {
        SwatchPicker(title: "Tint", color: tint)
        StudioSlider(title: "Tint Strength", value: amount, range: 0...0.85, editor: editor)
    }
}

private struct GradientFillEditor: View {
    let editor: StudioEditor

    private var colors: [RGBA] {
        if case .gradient(let c, _) = editor.style.background { c } else { [] }
    }

    private func color(_ i: Int) -> Binding<RGBA> {
        Binding(get: { colors[safe: i] ?? .white }, set: { c in
            editor.edit { g in
                guard case .gradient(var cs, let a) = g.style.background, cs.indices.contains(i) else { return }
                cs[i] = c
                g.style.background = .gradient(colors: cs, angle: a)
            }
        })
    }

    private var angle: Binding<Double> {
        Binding(get: {
            if case .gradient(_, let a) = editor.style.background { a } else { 45 }
        }, set: { a in
            editor.edit { g in
                if case .gradient(let cs, _) = g.style.background { g.style.background = .gradient(colors: cs, angle: a) }
            }
        })
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(StudioPalette.gradients.enumerated()), id: \.offset) { _, pair in
                Button {
                    editor.edit { $0.style.background = .gradient(colors: pair, angle: angle.wrappedValue) }
                } label: {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(LinearGradient(colors: pair.map(\.color), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Gradient \(pair[0].hex) to \(pair[1].hex)"))
            }
        }
        ForEach(colors.indices, id: \.self) { i in
            ColorRow(title: i == 0 ? "Start" : (i == colors.count - 1 ? "End" : "Middle"), color: color(i))
        }
        HStack {
            Button("Add Color") {
                editor.edit { g in
                    if case .gradient(let cs, let a) = g.style.background, cs.count < 5 {
                        g.style.background = .gradient(colors: cs + [cs.last!.mixed(with: cs.first!, 0.5)], angle: a)
                    }
                }
            }
            .disabled(colors.count >= 5)
            Button("Remove Color") {
                editor.edit { g in
                    if case .gradient(let cs, let a) = g.style.background, cs.count > 2 {
                        g.style.background = .gradient(colors: Array(cs.dropLast()), angle: a)
                    }
                }
            }
            .disabled(colors.count <= 2)
        }
        StudioSlider(title: "Angle", value: angle, range: 0...360, step: 5, format: .degrees, editor: editor)
    }
}

private struct MeshFillEditor: View {
    let editor: StudioEditor

    private var colors: [RGBA] {
        if case .mesh(let c) = editor.style.background { c } else { [] }
    }

    private func color(_ i: Int) -> Binding<RGBA> {
        Binding(get: { colors[safe: i] ?? .white }, set: { c in
            editor.edit { g in
                guard case .mesh(var cs) = g.style.background, cs.indices.contains(i) else { return }
                cs[i] = c
                g.style.background = .mesh(colors: cs)
            }
        })
    }

    var body: some View {
        ForEach(colors.indices, id: \.self) { i in
            ColorRow(title: "Color \(i + 1)", color: color(i))
        }
        HStack {
            Button("Add Color") {
                editor.edit { g in
                    if case .mesh(let cs) = g.style.background, cs.count < 6 {
                        g.style.background = .mesh(colors: cs + [cs.last!.mixed(with: .white, 0.3)])
                    }
                }
            }
            .disabled(colors.count >= 6)
            Button("Remove Color") {
                editor.edit { g in
                    if case .mesh(let cs) = g.style.background, cs.count > 2 { g.style.background = .mesh(colors: Array(cs.dropLast())) }
                }
            }
            .disabled(colors.count <= 2)
        }
    }
}

private struct TextureFillEditor: View {
    let editor: StudioEditor

    private var current: (TextureKind, RGBA) {
        if case .texture(let n, let t) = editor.style.background { (TextureKind(name: n), t) } else { (.noise, .white) }
    }

    private var tint: Binding<RGBA> {
        Binding(get: { current.1 }, set: { t in
            editor.edit { g in
                if case .texture(let n, _) = g.style.background { g.style.background = .texture(name: n, tint: t) }
            }
        })
    }

    var body: some View {
        let (kind, _) = current
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(TextureKind.allCases, id: \.self) { k in
                PickTile(title: k.title, selected: k == kind, action: {
                    editor.edit { $0.style.background = .texture(name: k.rawValue, tint: k.suggestedTint) }
                }) {
                    TextureFill(kind: k, tint: k.suggestedTint)
                        .frame(height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        SwatchPicker(title: "Tint", color: tint)
    }
}

private struct EffectFillEditor: View {
    let editor: StudioEditor

    private var params: FXParams {
        if case .fx(let p) = editor.style.background { p } else { FXKind.aurora.defaultParams }
    }

    private func param<T>(_ kp: WritableKeyPath<FXParams, T>) -> Binding<T> {
        Binding(get: { params[keyPath: kp] }, set: { v in
            editor.edit { g in
                guard case .fx(var p) = g.style.background else { return }
                p[keyPath: kp] = v
                g.style.background = .fx(p)
            }
        })
    }

    private func paletteColor(_ i: Int) -> Binding<RGBA> {
        Binding(get: { params.palette[safe: i] ?? .white }, set: { c in
            editor.edit { g in
                guard case .fx(var p) = g.style.background else { return }
                while p.palette.count <= i { p.palette.append(p.palette.last ?? .white) }
                p.palette[i] = c
                g.style.background = .fx(p)
            }
        })
    }

    private var baseOn: Binding<Bool> {
        Binding(get: { params.base != nil }, set: { on in param(\.base).wrappedValue = on ? params.palette.first?.darker(0.7) ?? .black : nil })
    }

    private var baseColor: Binding<RGBA> {
        Binding(get: { params.base ?? .black }, set: { c in param(\.base).wrappedValue = c })
    }

    var body: some View {
        let p = params
        EffectKindGrid(current: p.kind) { kind in
            editor.edit { $0.style.background = .fx(kind.defaultParams) }
        }
        ColorRow(title: "Color 1", color: paletteColor(0))
        ColorRow(title: "Color 2", color: paletteColor(1))
        ColorRow(title: "Color 3", color: paletteColor(2))
        Toggle("Base Color", isOn: baseOn)
        if p.base != nil { ColorRow(title: "Base", color: baseColor) }
        StudioSlider(title: "Speed", value: param(\.speed), range: 0.2...2, format: .multiplier, editor: editor)
        StudioSlider(title: "Intensity", value: param(\.intensity), range: 0.2...1.5, editor: editor)
        StudioSlider(title: p.kind.sizeKnob, value: param(\.p3), range: 0...1, editor: editor)
        if p.kind == .glyphRain {
            StudioSlider(title: "Glyph Size", value: param(\.p4), range: 0...1, editor: editor)
            StudioSlider(title: "Trail", value: param(\.p5), range: 0...1, editor: editor)
        }
        if p.kind.hasWind {
            StudioSlider(title: "Wind", value: param(\.drift), range: -1...1, format: .plain, editor: editor)
        }
        if p.kind.hasVariants {
            Stepper(value: param(\.style), in: 0...3) {
                LabeledContent("Variant", value: "\(p.style + 1)")
            }
        }
        Picker("Pointer", selection: param(\.pointer)) {
            ForEach(FXPointer.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
    }
}

/// Live thumbnails of all effects. A thumbnail plays while the pointer is over it.
private struct EffectKindGrid: View {
    let current: FXKind
    let pick: (FXKind) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(FXKind.allCases, id: \.self) { kind in
                EffectThumb(kind: kind, selected: kind == current) { pick(kind) }
            }
        }
    }
}

private struct EffectThumb: View {
    let kind: FXKind
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        PickTile(title: kind.title, selected: selected, action: action) {
            FXView(params: kind.defaultParams, pointer: nil, isActive: hovering)
                .frame(height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onHover { hovering = $0 }
        }
    }
}

private struct PhotoFillEditor: View {
    let editor: StudioEditor

    private func value(_ dim: Bool) -> Binding<Double> {
        Binding(get: {
            if case .image(_, let d, let b) = editor.style.background { dim ? d : b } else { 0 }
        }, set: { v in
            editor.edit { g in
                if case .image(let p, let d, let b) = g.style.background {
                    g.style.background = .image(path: p, dim: dim ? v : d, blur: dim ? b : v)
                }
            }
        })
    }

    var body: some View {
        if case .image(let path, _, _) = editor.style.background {
            LabeledContent("File", value: URL(fileURLWithPath: path).lastPathComponent)
        }
        Button("Choose Photo…") {
            guard let path = StudioEditor.importImage() else { return }
            editor.edit { g in
                if case .image(_, let d, let b) = g.style.background { g.style.background = .image(path: path, dim: d, blur: b) }
            }
        }
        StudioSlider(title: "Dim", value: value(true), range: 0...0.8, editor: editor)
        StudioSlider(title: "Blur", value: value(false), range: 0...40, step: 1, format: .points, editor: editor)
    }
}

private struct WallpaperFillEditor: View {
    let editor: StudioEditor

    private func value(_ dim: Bool) -> Binding<Double> {
        Binding(get: {
            if case .wallpaper(let b, let d) = editor.style.background { dim ? d : b } else { 0 }
        }, set: { v in
            editor.edit { g in
                if case .wallpaper(let b, let d) = g.style.background {
                    g.style.background = .wallpaper(blur: dim ? b : v, dim: dim ? v : d)
                }
            }
        })
    }

    var body: some View {
        Text("Shows your desktop picture behind the popup, blurred.")
            .font(.callout)
            .foregroundStyle(.secondary)
        StudioSlider(title: "Blur", value: value(false), range: 0...60, step: 1, format: .points, editor: editor)
        StudioSlider(title: "Dim", value: value(true), range: 0...0.8, editor: editor)
    }
}

// MARK: - Labels

private struct LabelSection: View {
    let editor: StudioEditor

    private var size: Binding<Int> {
        Binding(get: {
            let s = editor.style.labels.size
            return s < 10.8 ? 0 : (s < 12.3 ? 1 : 2)
        }, set: { i in editor.edit { $0.style.labels.size = [10, 11.5, 13][i] } })
    }

    var body: some View {
        Section("Labels") {
            Picker("Show Names", selection: editor.binding(\.style.labels.mode)) {
                Text("Always").tag(LabelMode.always)
                Text("On Hover").tag(LabelMode.onHover)
                Text("Off").tag(LabelMode.off)
            }
            .pickerStyle(.segmented)
            Picker("Color", selection: editor.binding(\.style.labels.colorMode)) {
                Text("Auto").tag(LabelColorMode.auto)
                Text("White").tag(LabelColorMode.white)
                Text("Black").tag(LabelColorMode.black)
                Text("Custom").tag(LabelColorMode.custom)
            }
            .pickerStyle(.segmented)
            if editor.style.labels.colorMode == .custom {
                ColorRow(title: "Label Color", color: editor.binding(\.style.labels.color))
            }
            Picker("Size", selection: size) {
                Text("S").tag(0)
                Text("M").tag(1)
                Text("L").tag(2)
            }
            .pickerStyle(.segmented)
            Picker("Font", selection: editor.binding(\.style.labels.design)) {
                Text("System").tag(FontDesignChoice.system)
                Text("Rounded").font(.system(.body, design: .rounded)).tag(FontDesignChoice.rounded)
                Text("Serif").font(.system(.body, design: .serif)).tag(FontDesignChoice.serif)
                Text("Mono").font(.system(.body, design: .monospaced)).tag(FontDesignChoice.monospaced)
            }
            Toggle("Text Shadow", isOn: editor.binding(\.style.labels.shadow))
            Toggle("Text Backdrop", isOn: editor.binding(\.style.labels.backdrop))
        }
    }
}
