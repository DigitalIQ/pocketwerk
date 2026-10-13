import AppKit
import SwiftUI

// MARK: - Colors

/// Codable color. All model colors use this, never NSColor/Color directly.
nonisolated struct RGBA: Codable, Hashable, Sendable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double = 1

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// "#RRGGBB" or "#RRGGBBAA"
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        if s.count == 8 {
            self.init(Double((v >> 24) & 0xFF) / 255, Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
        } else {
            self.init(Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
        }
    }

    var hex: String {
        String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
    var cgColor: CGColor { nsColor.cgColor }

    init(_ ns: NSColor) {
        let c = ns.usingColorSpace(.sRGB) ?? .black
        self.init(Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent), Double(c.alphaComponent))
    }

    static let white = RGBA(1, 1, 1)
    static let black = RGBA(0, 0, 0)
    static let clear = RGBA(0, 0, 0, 0)
}

// MARK: - Items

nonisolated enum ItemKind: String, Codable, CaseIterable, Sendable {
    case app, file, folder, link
}

/// One entry in a group: an app, a file, a folder, or a web link.
nonisolated struct DockItem: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var kind: ItemKind
    /// File URL for app/file/folder, http(s) or any scheme for links.
    var url: URL
    var customName: String?
    var addedAt = Date()
    var lastOpenedAt: Date?
    var openCount = 0

    init(kind: ItemKind, url: URL, customName: String? = nil) {
        self.kind = kind
        self.url = url
        self.customName = customName
    }

    /// Builds an item from any URL and detects its kind.
    init(url: URL) {
        if url.isFileURL {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            if url.pathExtension == "app" {
                self.init(kind: .app, url: url)
            } else if isDir.boolValue {
                self.init(kind: .folder, url: url)
            } else {
                self.init(kind: .file, url: url)
            }
        } else {
            self.init(kind: .link, url: url)
        }
    }

    var displayName: String {
        if let customName, !customName.isEmpty { return customName }
        switch kind {
        case .app:
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        case .file, .folder:
            return FileManager.default.displayName(atPath: url.path)
        case .link:
            return url.host(percentEncoded: false) ?? url.absoluteString
        }
    }

    /// False when a file item points to something that no longer exists.
    var exists: Bool {
        kind == .link || FileManager.default.fileExists(atPath: url.path)
    }
}

// MARK: - Style

nonisolated enum LayoutKind: String, Codable, CaseIterable, Sendable {
    case grid, list, tiles
}

nonisolated enum SortOrder: String, Codable, CaseIterable, Sendable {
    case manual, name, kind, dateAdded, lastOpened, mostOpened
}

/// Animated background kinds ("Animated" + folder app "living effects"). The Theme module renders them.
nonisolated enum FXKind: String, Codable, CaseIterable, Sendable {
    case arcs, curtains, waves, marble, snow, embers, glyphRain, blobs, fur
    case rain, fog, driftingLight, lava, aurora, starfield, plasma, bubbles, ripples
}

nonisolated enum HeaderAlignment: String, Codable, CaseIterable, Sendable {
    case leading, center, hidden
}

nonisolated enum LabelMode: String, Codable, CaseIterable, Sendable {
    case always, onHover, off
}

nonisolated enum LabelColorMode: String, Codable, CaseIterable, Sendable {
    case auto, white, black, custom
}

nonisolated enum HoverHighlight: String, Codable, CaseIterable, Sendable {
    case none, subtle, heavy
}

nonisolated enum AppearanceChoice: String, Codable, CaseIterable, Sendable {
    case system, light, dark
}

nonisolated enum Background: Codable, Hashable, Sendable {
    case solid(RGBA)
    /// Linear gradient. angle in degrees, 0 = left to right, 90 = top to bottom.
    case gradient(colors: [RGBA], angle: Double)
    /// Radial or mesh-like soft gradient from several colors.
    case mesh(colors: [RGBA])
    /// User photo. dim 0...1 darkens it, blur in points.
    case image(path: String, dim: Double, blur: Double)
    /// System material / Liquid Glass. tint is laid over the glass.
    case glass(tint: RGBA, intensity: Double)
    /// Animated background reacting to the pointer. palette: 1-3 colors, base: optional fill under the effect.
    case fx(kind: FXKind, palette: [RGBA], speed: Double, intensity: Double)
    /// The real desktop wallpaper behind the popup, blurred (folder app wallpaper glass).
    case wallpaper(blur: Double, dim: Double)
    /// Procedural texture by name, e.g. "knit", "ice", "leopard", "tiger", "cardboard", "paper", "noise".
    case texture(name: String, tint: RGBA)
}

nonisolated struct BorderStyle: Codable, Hashable, Sendable {
    var color: RGBA = RGBA(1, 1, 1, 0.25)
    var width: Double = 1
    /// When set (2+ colors), the border is a 135 degree gradient instead of `color`.
    var gradient: [RGBA]?
}

nonisolated enum FontDesignChoice: String, Codable, CaseIterable, Sendable {
    case system, rounded, serif, monospaced
}

nonisolated struct LabelStyle: Codable, Hashable, Sendable {
    var mode: LabelMode = .always
    var design: FontDesignChoice = .system
    /// Optional custom font family name (overrides design when set and installed).
    var family: String?
    var size: Double = 11
    var weight: Double = 0.23 // NSFont.Weight raw value, 0.23 = medium
    var colorMode: LabelColorMode = .auto
    /// Used when colorMode == .custom.
    var color: RGBA = .white
    var shadow = true
    /// Small translucent plate behind the label text.
    var backdrop = false
}

nonisolated struct GroupStyle: Codable, Hashable, Sendable {
    var background: Background = .glass(tint: RGBA(0.1, 0.1, 0.12, 0.35), intensity: 1)
    /// Extra Liquid Glass amount over any fill, 0 = off, 1 = full (popup app "Glass Effect" slider).
    var glassAmount: Double = 0
    /// Opacity of the whole fill, 0...1 (folder app "Opacity").
    var opacity: Double = 1
    var border: BorderStyle? = BorderStyle()
    var cornerRadius: Double = 24
    var appearance: AppearanceChoice = .system
    var layout: LayoutKind = .grid
    /// 0 = adaptive (choose from item count).
    var columns: Int = 0
    /// 0 = unlimited. When the items need more rows, the popup pages (or scrolls when paged == false).
    var maxRows: Int = 0
    var paged = true
    var iconSize: Double = 56
    /// Tight 8, Normal 14, Airy 22.
    var spacing: Double = 14
    var padding: Double = 18
    var labels = LabelStyle()
    var hover: HoverHighlight = .subtle
    var highlightColor: RGBA = RGBA(1, 1, 1, 0.18)
    var shadow = true
    var header: HeaderAlignment = .leading
    /// Show a dot under running apps.
    var runningIndicator = true

    static let `default` = GroupStyle()
}

// MARK: - Icons (Dock icon / folder icon)

nonisolated enum IconShape: String, Codable, CaseIterable, Sendable {
    case squircle, roundedSquare, circle, square, folder, none
}

nonisolated enum StackDirection: String, Codable, CaseIterable, Sendable {
    case downRight, down, downLeft
}

/// folder app "Stack" style: item icons fanned like cards.
nonisolated struct StackOptions: Codable, Hashable, Sendable {
    var direction: StackDirection = .downRight
    var depth: Int = 3 // 2...4
    var fade = true
    var blur = false
    var scale: Double = 0.8
    var spacing: Double = 0.12
    var shuffle = false
}

nonisolated enum IconContent: Codable, Hashable, Sendable {
    /// Mini grid of the first item icons (iOS folder / popup app live icon). count: 0 = auto, 4, 9, 16.
    case itemGrid(count: Int)
    /// Fanned stack of the first item icons (folder app "Stack").
    case itemStack
    case symbol(name: String)
    case emoji(String)
    case text(String)
    /// First letters of the name.
    case monogram
    /// Any image file on disk (own PNG).
    case image(path: String)
}

nonisolated struct IconSpec: Codable, Hashable, Sendable {
    var content: IconContent = .itemGrid(count: 4)
    var shape: IconShape = .squircle
    /// nil = derive from the (first) group's style background ("match theme").
    var background: Background?
    var foreground: RGBA = .white
    var border: BorderStyle?
    /// Optional icon pack id used for `.symbol` rendering (Icons module decides meaning).
    var pack: String?
    var opacity: Double = 1
    /// 0 = clear glass, 1 = fully frosted.
    var matte: Double = 0
    /// Smaller gaps between grid icons.
    var dense = false
    /// Circular sub-icons in the grid.
    var roundItems = false
    var glossy = true
    /// Drop shadow / elevation.
    var lift = true
    var stack = StackOptions()
}

// MARK: - Hotkey

/// Carbon key code plus Carbon modifier flags (cmdKey, optionKey, controlKey, shiftKey).
nonisolated struct Hotkey: Codable, Hashable, Sendable {
    var keyCode: UInt32
    var modifiers: UInt32
}

// MARK: - Groups and Dock slots

/// A group ("Pop" / "folder app"): an ordered set of items with its own look.
nonisolated struct ItemGroup: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var items: [DockItem] = []
    var style = GroupStyle()
    /// Id of the theme last applied, for display only.
    var themeID: String?
    var sortOrder: SortOrder = .manual
    var hotkey: Hotkey?
    var icon = IconSpec()
    /// Hidden from the "all groups" carousel; still reachable by its own Dock icon or hotkey.
    var hiddenFromAll = false
    /// Automatic group whose items are computed, not stored.
    var smart: SmartGroupKind?

    init(name: String) { self.name = name }

    var sortedItems: [DockItem] {
        switch sortOrder {
        case .manual: return items
        case .name: return items.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        case .kind: return items.sorted { ($0.kind.rawValue, $0.displayName) < ($1.kind.rawValue, $1.displayName) }
        case .dateAdded: return items.sorted { $0.addedAt > $1.addedAt }
        case .lastOpened: return items.sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
        case .mostOpened: return items.sorted { $0.openCount > $1.openCount }
        }
    }
}

nonisolated enum SmartGroupKind: String, Codable, CaseIterable, Sendable {
    /// Top items by open count across all groups (group app "Most Used").
    case mostUsed
    /// Items opened most recently across all groups.
    case recentlyOpened
    /// Apps currently running.
    case runningApps
}

/// One icon in the Dock. Shows one or more groups; the popup swipes between them.
nonisolated struct DockSlot: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var groupIDs: [UUID]
    /// nil = use the first group's icon.
    var icon: IconSpec?
    var hotkey: Hotkey?
    /// Path of the generated launcher bundle, nil when not installed.
    var launcherPath: String?

    init(name: String, groupIDs: [UUID]) {
        self.name = name
        self.groupIDs = groupIDs
    }
}

// MARK: - Themes

/// A named look. Applying it changes the visual parts of a GroupStyle and the icon look,
/// but keeps layout, columns, icon size and spacing.
nonisolated struct Theme: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var style: GroupStyle
    var icon: IconSpec?
    var isBuiltIn = false
    /// Free-form category for the gallery, e.g. "Glass", "Animated", "Gradient".
    var category: String = "Custom"
}

// MARK: - Dock profiles (saved Dock layouts)

/// A saved copy of the whole macOS Dock (apps, others, and Dock settings).
nonisolated struct DockProfile: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var createdAt = Date()
    /// Raw property list data of the relevant com.apple.dock keys.
    var plistData: Data
    var hotkey: Hotkey?
    /// Quit running regular apps that are not in the profile (except `keepRunning`).
    var quitOthers = false
    /// Launch every app of the profile after applying.
    var launchApps = false
    /// Bundle ids never quit by `quitOthers`.
    var keepRunning: [String] = []
    /// Files, folders, project paths or URLs opened after applying.
    var openAfterApply: [URL] = []
    /// Free note ("last context").
    var note: String = ""
    /// Skipped by "next profile" cycling.
    var excludedFromCycle = false
}

/// profile app-style custom spacer: a tiny Dock tile that shows only text or an image.
nonisolated struct CustomSpacer: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var text: String = ""
    var imagePath: String?
    var icon = IconSpec(content: .text(""), shape: .none)
    var launcherPath: String?
}

// MARK: - Settings

nonisolated enum PopupPlacement: String, Codable, CaseIterable, Sendable {
    case nearDock, mouse, center
}

nonisolated enum AnimationSpeed: String, Codable, CaseIterable, Sendable {
    case slow, medium, fast, off
}

nonisolated enum MenuBarClick: String, Codable, CaseIterable, Sendable {
    case carousel, menu
}

nonisolated struct AppSettings: Codable, Hashable, Sendable {
    var showMenuBarIcon = true
    var showMainDockIcon = true
    var launchAtLogin = false
    var closeAfterOpen = true
    var placement: PopupPlacement = .nearDock
    /// Launchers stay running: faster reopen and live icon, but a running dot in the Dock.
    var keepLaunchersRunning = false
    var mainHotkey: Hotkey?
    var assistantEnabled = true
    var suggestionsEnabled = true
    /// Folder for an extra JSON copy of the library (e.g. iCloud Drive), nil = off.
    var syncFolderPath: String?
    var confirmBeforeOpenAll = true
    /// Seconds between launches for "Open All".
    var openAllDelay: Double = 0.25
    var animationSpeed: AnimationSpeed = .medium
    /// Gap between Dock and popup in points.
    var popoverOffset: Double = 10
    var lockSizeWhileSwiping = false
    var menuBarClick: MenuBarClick = .carousel
    /// ⌥⇧1...9 open groups 1...9 when they have no own hotkey.
    var numberHotkeys = true
    /// Profile applied at app start, nil = none.
    var startupProfileID: UUID?
    var soundEffects = false
    /// Hotkey that applies the next profile in order.
    var nextProfileHotkey: Hotkey?
}

// MARK: - Library (root of everything persisted)

nonisolated struct Library: Codable, Hashable, Sendable {
    var version = 1
    var groups: [ItemGroup] = []
    var slots: [DockSlot] = []
    var customThemes: [Theme] = []
    var profiles: [DockProfile] = []
    var spacers: [CustomSpacer] = []
    var settings = AppSettings()

    func group(_ id: UUID) -> ItemGroup? { groups.first { $0.id == id } }
    func slot(_ id: UUID) -> DockSlot? { slots.first { $0.id == id } }
}
