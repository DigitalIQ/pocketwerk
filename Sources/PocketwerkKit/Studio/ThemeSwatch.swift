import SwiftUI

/// A small live picture of a look: its fill, border, label color and three sample items.
struct ThemeSwatch: View {
    var style: GroupStyle
    var items: [DockItem] = []
    /// Animated effects play only while this is true (on hover in the gallery).
    var animate = false
    var height: CGFloat = 64

    var body: some View {
        let radius = min(style.cornerRadius * 0.5, 14)
        var mini = style
        mini.cornerRadius = radius
        mini.border = style.border.map { b in var b = b; b.width = min(b.width, 1.5); return b }
        let label = style.labels.resolvedColor(on: style.background, dark: true)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    sample(i, label: label)
                }
            }
            RoundedRectangle(cornerRadius: 2)
                .fill(label.color.opacity(0.85))
                .frame(width: height * 0.55, height: 4)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .bottomLeading)
        .styleSurface(mini, isActive: animate)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func sample(_ i: Int, label: RGBA) -> some View {
        let size = height * 0.32
        if i < items.count {
            Image(nsImage: IconRenderer.icon(for: items[i], size: size))
                .resizable()
                .frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(label.color.opacity(0.75 - Double(i) * 0.18))
                .frame(width: size * 0.8, height: size * 0.8)
                .frame(width: size, height: size)
        }
    }
}
