import SwiftUI

/// How a slider value is shown.
enum SliderFormat {
    case percent, points, degrees, multiplier, plain

    func text(_ v: Double) -> String {
        switch self {
        case .percent: "\(Int((v * 100).rounded())) %"
        case .points: "\(Int(v.rounded())) pt"
        case .degrees: "\(Int(v.rounded()))°"
        case .multiplier: String(format: "%.1f×", v)
        case .plain: String(format: "%.2f", v)
        }
    }
}

/// A titled slider with its value. One drag is one undo step.
struct StudioSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double? = nil
    var format: SliderFormat = .percent
    let editor: StudioEditor

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(format.text(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            Group {
                if let step {
                    Slider(value: clamped, in: range, step: step, onEditingChanged: editor.dragChanged) { Text(title) }
                } else {
                    Slider(value: clamped, in: range, onEditingChanged: editor.dragChanged) { Text(title) }
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .accessibilityLabel(Text(title))
            .accessibilityValue(format.text(value))
        }
    }

    private var clamped: Binding<Double> {
        Binding(get: { min(range.upperBound, max(range.lowerBound, value)) }, set: { value = $0 })
    }
}

/// Twenty color swatches in two rows plus a custom color well. Keeps the current alpha.
struct SwatchPicker: View {
    let title: LocalizedStringKey
    @Binding var color: RGBA
    var supportsOpacity = false
    /// When set, a third row offers gradient variants of the first-row colors.
    var onGradient: ((RGBA) -> Void)? = nil

    init(title: LocalizedStringKey, color: Binding<RGBA>, supportsOpacity: Bool = false, onGradient: ((RGBA) -> Void)? = nil) {
        self.title = title
        self._color = color
        self.supportsOpacity = supportsOpacity
        self.onGradient = onGradient
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                ColorPicker(selection: $color.swiftUIColor, supportsOpacity: supportsOpacity) { Text("Custom Color") }
                    .labelsHidden()
                    .help(Text("Custom Color"))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 16, maximum: 26), spacing: 5), count: 10), spacing: 6) {
                ForEach(StudioPalette.swatches, id: \.name) { swatch in
                    let selected = swatch.color.hex == color.hex
                    Button {
                        color = swatch.color.alpha(color.a)
                    } label: {
                        Circle()
                            .fill(swatch.color.color)
                            .overlay(Circle().strokeBorder(.primary.opacity(0.18), lineWidth: 0.5))
                            .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: selected ? 2 : 0).padding(-3))
                            .aspectRatio(1, contentMode: .fit)
                    }
                    .buttonStyle(.plain)
                    .help(Text(swatch.name))
                    .accessibilityLabel(Text(swatch.name))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 3)
            if let onGradient {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 16, maximum: 26), spacing: 5), count: 10), spacing: 6) {
                    ForEach(StudioPalette.swatches.prefix(10), id: \.name) { swatch in
                        Button { onGradient(swatch.color) } label: {
                            Circle()
                                .fill(LinearGradient(colors: StudioPalette.gradientPair(swatch.color).map(\.color),
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(Circle().strokeBorder(.primary.opacity(0.18), lineWidth: 0.5))
                                .aspectRatio(1, contentMode: .fit)
                        }
                        .buttonStyle(.plain)
                        .help(Text("\(swatch.name) Gradient"))
                        .accessibilityLabel(Text("\(swatch.name) Gradient"))
                    }
                }
                .padding(.horizontal, 3)
            }
        }
    }
}

/// A labeled color well.
struct ColorRow: View {
    let title: LocalizedStringKey
    @Binding var color: RGBA
    var supportsOpacity = false

    var body: some View {
        ColorPicker(selection: $color.swiftUIColor, supportsOpacity: supportsOpacity) { Text(title) }
    }
}

/// None, one color, or a gradient border, plus the width.
struct BorderEditor: View {
    @Binding var border: BorderStyle?
    let editor: StudioEditor

    enum Mode: String, CaseIterable, Identifiable {
        case none, color, gradient
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .none: "None"
            case .color: "Color"
            case .gradient: "Gradient"
            }
        }
    }

    private var mode: Binding<Mode> {
        Binding(get: {
            guard let border else { return .none }
            return (border.gradient?.count ?? 0) >= 2 ? .gradient : .color
        }, set: { m in
            let current = border ?? BorderStyle()
            switch m {
            case .none: border = nil
            case .color: border = BorderStyle(color: current.color, width: max(0.5, current.width), gradient: nil)
            case .gradient:
                let g = current.gradient ?? [current.color.opaque.lighter(0.4), current.color.opaque.darker(0.3)]
                border = BorderStyle(color: current.color, width: max(1, current.width), gradient: g)
            }
        })
    }

    private func gradientColor(_ i: Int) -> Binding<RGBA> {
        Binding(get: { border?.gradient?[safe: i] ?? .white }, set: { c in
            guard var b = border, var g = b.gradient, g.indices.contains(i) else { return }
            g[i] = c
            b.gradient = g
            border = b
        })
    }

    private var width: Binding<Double> {
        Binding(get: { border?.width ?? 1 }, set: { w in border?.width = w })
    }

    private var single: Binding<RGBA> {
        Binding(get: { border?.color ?? .white }, set: { c in border?.color = c })
    }

    var body: some View {
        Picker(selection: mode) {
            ForEach(Mode.allCases) { Text($0.title).tag($0) }
        } label: { Text("Border") }
        .pickerStyle(.segmented)
        switch mode.wrappedValue {
        case .none:
            EmptyView()
        case .color:
            ColorRow(title: "Color", color: single, supportsOpacity: true)
            StudioSlider(title: "Width", value: width, range: 0.5...6, step: 0.5, format: .points, editor: editor)
        case .gradient:
            ColorRow(title: "Start", color: gradientColor(0))
            ColorRow(title: "End", color: gradientColor((border?.gradient?.count ?? 2) - 1))
            StudioSlider(title: "Width", value: width, range: 0.5...6, step: 0.5, format: .points, editor: editor)
        }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

/// Small glyph of an icon shape for pickers.
struct IconShapeGlyph: View {
    var shape: IconShape
    var size: CGFloat = 20

    var body: some View {
        Group {
            switch shape {
            case .squircle: RoundedRectangle(cornerRadius: size * 0.2237 * 1.1, style: .continuous).fill(.primary.opacity(0.75))
            case .roundedSquare: RoundedRectangle(cornerRadius: size * 0.14).fill(.primary.opacity(0.75))
            case .circle: Circle().fill(.primary.opacity(0.75))
            case .square: Rectangle().fill(.primary.opacity(0.75))
            case .folder: Image(systemName: "folder.fill").resizable().scaledToFit()
            case .none: Image(systemName: "square.dashed").resizable().scaledToFit()
            }
        }
        .frame(width: size, height: size)
    }

    static func title(_ shape: IconShape) -> String {
        switch shape {
        case .squircle: String(localized: "Squircle")
        case .roundedSquare: String(localized: "Rounded")
        case .circle: String(localized: "Circle")
        case .square: String(localized: "Square")
        case .folder: String(localized: "Folder")
        case .none: String(localized: "No Shape")
        }
    }
}

/// A selectable tile with a picture and a caption, used for icon modes, textures and effects.
struct PickTile<Picture: View>: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @ViewBuilder var picture: () -> Picture
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                picture()
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(selected ? Color.accentColor : .primary.opacity(hovering ? 0.25 : 0.08), lineWidth: selected ? 2 : 1)
                    )
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(selected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
