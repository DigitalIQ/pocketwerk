import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum StudioTab: String, CaseIterable, Identifiable {
    case icon, popup, grid
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .icon: "Icon"
        case .popup: "Popup"
        case .grid: "Grid"
        }
    }
}

/// Backdrops for the preview canvas.
enum PreviewWallpaper: String, CaseIterable, Identifiable {
    case desktop, dusk, meadow, ocean, graphite, paper
    var id: String { rawValue }

    var title: String {
        switch self {
        case .desktop: String(localized: "Desktop Picture")
        case .dusk: String(localized: "Dusk")
        case .meadow: String(localized: "Meadow")
        case .ocean: String(localized: "Ocean")
        case .graphite: String(localized: "Graphite")
        case .paper: String(localized: "Paper")
        }
    }

    var colors: [RGBA] {
        switch self {
        case .desktop: [RGBA(0.25, 0.3, 0.4), RGBA(0.15, 0.17, 0.22)]
        case .dusk: ["#2B1B4F", "#7A3E8E", "#E0735A", "#F6B26B", "#3D2C6B"].map(RGBA.init(hex:))
        case .meadow: ["#1F4D3A", "#6BA368", "#D8E5A3", "#9CCB86", "#2E6B4F"].map(RGBA.init(hex:))
        case .ocean: ["#06233F", "#0F5E8C", "#5CC5D9", "#BFEAF0", "#0B3C66"].map(RGBA.init(hex:))
        case .graphite: ["#121316", "#2A2D33", "#3C4048", "#1B1D21"].map(RGBA.init(hex:))
        case .paper: ["#F4F1EA", "#E6E1D6", "#FBFAF7", "#DCD6CA"].map(RGBA.init(hex:))
        }
    }
}

enum PreviewScheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
}

/// State and edit helpers of one open Design Studio. Every edit goes through `LibraryStore.updateGroup`,
/// so changes apply live everywhere and can be undone. A slider drag records one undo step.
@Observable
final class StudioEditor {
    let store: LibraryStore
    let groupID: UUID
    var tab: StudioTab = .icon
    var wallpaper: PreviewWallpaper = .dusk
    var previewScheme: PreviewScheme = .system
    var search = ""

    @ObservationIgnored private var dragging = false
    @ObservationIgnored private var pendingUndo = false

    init(store: LibraryStore, groupID: UUID) {
        self.store = store
        self.groupID = groupID
    }

    var exists: Bool { store.group(groupID) != nil }
    var group: ItemGroup { store.group(groupID) ?? ItemGroup(name: "") }
    var style: GroupStyle { group.style }
    var icon: IconSpec { group.icon }

    func edit(_ change: (inout ItemGroup) -> Void) {
        let undoable = !dragging || pendingUndo
        pendingUndo = false
        store.updateGroup(groupID, undoable: undoable, change)
    }

    func binding<T>(_ keyPath: WritableKeyPath<ItemGroup, T>) -> Binding<T> {
        Binding(get: { self.group[keyPath: keyPath] }, set: { value in self.edit { $0[keyPath: keyPath] = value } })
    }

    /// Call from `Slider(onEditingChanged:)`: the whole drag becomes one undo step.
    func dragChanged(_ editing: Bool) {
        dragging = editing
        if editing { pendingUndo = true }
    }

    // MARK: Whole-look actions

    func apply(_ theme: Theme) {
        store.applyTheme(theme, to: groupID)
    }

    func randomize() { store.randomizeLook(of: groupID) }
    func reset() { store.resetLook(of: groupID) }

    @discardableResult
    func saveTheme(named name: String) -> Theme? { store.saveTheme(from: groupID, name: name) }

    // MARK: Files

    /// Lets the user pick an image and copies it into the data folder, so it survives moves and needs no folder access later.
    static func importImage() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = String(localized: "Choose")
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let dir = LibraryStore.directory.appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("\(UUID().uuidString).\(url.pathExtension.isEmpty ? "png" : url.pathExtension)")
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            return dest.path
        } catch {
            return url.path
        }
    }
}

// MARK: - Palette

/// Swatches offered for colors: two rows of ten.
enum StudioPalette {
    static let swatches: [(name: String, color: RGBA)] = [
        ("White", "#FFFFFF"), ("Silver", "#D9DCE1"), ("Gray", "#8E949C"), ("Blue", "#2F6FED"), ("Teal", "#18A6B5"),
        ("Green", "#2FAF6B"), ("Yellow", "#F2C230"), ("Orange", "#F28A2E"), ("Red", "#E5484D"), ("Pink", "#E5609E"),
        ("Purple", "#8A5CF5"), ("Black", "#1C1D21"), ("Sky", "#A9C7FF"), ("Navy", "#0E3B7A"), ("Deep Teal", "#0F5C55"),
        ("Forest", "#1E5E3A"), ("Ochre", "#8C6A10"), ("Rust", "#8A3F12"), ("Wine", "#7A1F2B"), ("Plum", "#4A2A7A"),
    ].map { ($0.0, RGBA(hex: $0.1)) }

    /// A gradient made from one swatch: lighter at the top left, deeper at the bottom right.
    static func gradientPair(_ c: RGBA) -> [RGBA] {
        c.luminance > 0.8 ? [c, c.darker(0.18)] : [c.lighter(0.28), c.darker(0.32)]
    }

    static let gradients: [[RGBA]] = [
        ["#FFB49C", "#FF7194"], ["#1C2EC4", "#52A6FF"], ["#9DE8C6", "#2F9F90"], ["#5D257C", "#1ECFE0"],
        ["#FAD625", "#FF5052"], ["#160D2B", "#6C3295"], ["#40251A", "#BA6B41"], ["#112229", "#2E5566"],
    ].map { $0.map(RGBA.init(hex:)) }
}

extension Binding where Value == RGBA {
    /// A SwiftUI color binding for ColorPicker.
    var swiftUIColor: Binding<Color> {
        Binding<Color>(get: { wrappedValue.color }, set: { wrappedValue = RGBA(NSColor($0)) })
    }
}
