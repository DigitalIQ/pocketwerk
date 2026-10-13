import SwiftUI

// OWNER: design agent. Placeholder with the final API.

enum ThemeLibrary {
    /// All built-in themes (target: 23+ incl. Animated) and folder app-like presets (target: 64).
    static let builtIn: [Theme] = [
        Theme(id: "glass-dark", name: "Glas Dunkel", style: GroupStyle(), isBuiltIn: true, category: "Glass"),
        Theme(id: "forest", name: "Forest", style: {
            var s = GroupStyle()
            s.background = .gradient(colors: [RGBA(hex: "#1E3D2F"), RGBA(hex: "#0B1F17")], angle: 90)
            return s
        }(), isBuiltIn: true, category: "Gradient"),
    ]

    /// Applies the visual parts of a theme, keeps layout, columns, icon size, spacing, padding.
    static func apply(_ theme: Theme, to style: GroupStyle) -> GroupStyle {
        var s = theme.style
        s.layout = style.layout
        s.columns = style.columns
        s.iconSize = style.iconSize
        s.spacing = style.spacing
        s.padding = style.padding
        s.maxRows = style.maxRows
        s.paged = style.paged
        s.header = style.header
        s.labels.mode = style.labels.mode
        return s
    }

    /// Applies the look of a theme icon, keeps the content (grid, symbol, emoji ...).
    static func apply(_ themeIcon: IconSpec, to icon: IconSpec) -> IconSpec {
        var i = themeIcon
        i.content = icon.content
        return i
    }
}
