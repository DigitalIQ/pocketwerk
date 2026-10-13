import SwiftUI

// OWNER: design agent. Placeholder with the final API.

/// Renders a `Background` as a SwiftUI view, clipped by the caller.
/// `pointer` is the pointer location in the view's coordinate space (nil = outside).
/// `isActive` false means the popup is hidden: animations must pause.
struct StyleBackgroundView: View {
    var background: Background
    var pointer: CGPoint? = nil
    var isActive: Bool = true

    var body: some View {
        switch background {
        case .solid(let c):
            c.color
        case .gradient(let colors, let angle):
            LinearGradient(colors: colors.map(\.color), startPoint: UnitPoint.from(angle: angle, end: false), endPoint: UnitPoint.from(angle: angle, end: true))
        case .mesh(let colors):
            LinearGradient(colors: colors.map(\.color), startPoint: .topLeading, endPoint: .bottomTrailing)
        case .image(let path, let dim, let blur):
            if let img = NSImage(contentsOfFile: path) {
                Image(nsImage: img).resizable().scaledToFill().blur(radius: blur).overlay(Color.black.opacity(dim))
            } else {
                Color.gray
            }
        case .glass(let tint, _):
            Rectangle().fill(.ultraThinMaterial).overlay(tint.color)
        case .fx(_, let palette, _, _):
            LinearGradient(colors: palette.map(\.color), startPoint: .top, endPoint: .bottom)
        case .wallpaper(let blur, let dim):
            if let url = NSScreen.main.flatMap({ NSWorkspace.shared.desktopImageURL(for: $0) }), let img = NSImage(contentsOf: url) {
                Image(nsImage: img).resizable().scaledToFill().blur(radius: blur).overlay(Color.black.opacity(dim))
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        case .texture(_, let tint):
            tint.color
        }
    }
}

extension UnitPoint {
    /// 0 degrees = left to right, 90 = top to bottom.
    static func from(angle: Double, end: Bool) -> UnitPoint {
        let rad = angle * .pi / 180
        let dx = cos(rad) / 2, dy = sin(rad) / 2
        return end ? UnitPoint(x: 0.5 + dx, y: 0.5 + dy) : UnitPoint(x: 0.5 - dx, y: 0.5 - dy)
    }
}
