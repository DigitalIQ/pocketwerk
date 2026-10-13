import AppKit

/// Screen edge the macOS Dock sits on.
nonisolated enum DockEdge: String, Codable, CaseIterable, Sendable {
    case bottom, left, right
}

/// The Dock settings that matter for placing the popup. Read only, never written.
nonisolated struct DockPrefs: Equatable, Sendable {
    var orientation: DockEdge = .bottom
    var tileSize: CGFloat = 48
    var largeSize: CGFloat = 64
    var magnification = false
    var autohide = false

    /// Extra room for magnified icons: the pointer is still over the magnified Dock when the popup appears.
    var magnificationGap: CGFloat { magnification ? max(0, largeSize - tileSize) : 0 }

    /// Current values from the Dock's preferences domain.
    static func current() -> DockPrefs {
        let domain = "com.apple.dock" as CFString
        CFPreferencesAppSynchronize(domain)
        func value(_ key: String) -> Any? { CFPreferencesCopyAppValue(key as CFString, domain) }
        var prefs = DockPrefs()
        if let o = value("orientation") as? String, let edge = DockEdge(rawValue: o) { prefs.orientation = edge }
        if let t = (value("tilesize") as? NSNumber)?.doubleValue, t > 0 { prefs.tileSize = t }
        if let l = (value("largesize") as? NSNumber)?.doubleValue, l > 0 { prefs.largeSize = l }
        prefs.magnification = (value("magnification") as? NSNumber)?.boolValue ?? false
        prefs.autohide = (value("autohide") as? NSNumber)?.boolValue ?? false
        return prefs
    }
}

/// A display as plain rectangles in global Cocoa coordinates (origin bottom left).
nonisolated struct ScreenBox: Equatable, Sendable {
    var frame: CGRect
    var visibleFrame: CGRect

    init(frame: CGRect, visibleFrame: CGRect) {
        self.frame = frame
        self.visibleFrame = visibleFrame
    }

    init(_ screen: NSScreen) {
        self.init(frame: screen.frame, visibleFrame: screen.visibleFrame)
    }

    @MainActor static var all: [ScreenBox] { NSScreen.screens.map(ScreenBox.init) }
}

/// Where the popup ends up and which way it rises while it fades in.
nonisolated struct PopupPlacementResult: Equatable, Sendable {
    var frame: CGRect
    var screenIndex: Int
    /// Dock edge the popup is attached to, nil when it floats (mouse, center).
    var edge: DockEdge?
    /// Unit direction toward the screen center, used for the open animation.
    var rise: CGVector
}

/// Pure placement math for the popup: Dock edge, Dock screen, gap for magnification, clamping.
nonisolated enum DockGeometry {
    /// A reserved strip narrower than this is not a Dock (rounding, notch, menu bar).
    static let minStrip: CGFloat = 12
    /// Space kept between the popup and the screen edges.
    static let margin: CGFloat = 6

    /// Edge and thickness of the Dock strip that the system reserves on this screen, nil when none.
    static func reservedStrip(of screen: ScreenBox) -> (edge: DockEdge, thickness: CGFloat)? {
        let f = screen.frame, v = screen.visibleFrame
        let bottom = v.minY - f.minY
        let left = v.minX - f.minX
        let right = f.maxX - v.maxX
        if bottom > minStrip, bottom >= left, bottom >= right { return (.bottom, bottom) }
        if left > minStrip, left >= right { return (.left, left) }
        if right > minStrip { return (.right, right) }
        return nil
    }

    /// Index of the screen that contains a point, nil when the point is on no screen.
    static func screenIndex(containing point: CGPoint, in screens: [ScreenBox]) -> Int? {
        if let i = screens.firstIndex(where: { $0.frame.contains(point) }) { return i }
        // Points on the far edge (maxX/maxY) still belong to the screen.
        return screens.firstIndex { $0.frame.insetBy(dx: -1, dy: -1).contains(point) }
    }

    /// The screen that holds the Dock: the pointer's screen when there is one, otherwise
    /// the screen with a reserved Dock strip, otherwise the first screen.
    static func dockScreenIndex(screens: [ScreenBox], pointer: CGPoint?, prefs: DockPrefs) -> Int {
        guard !screens.isEmpty else { return 0 }
        if let pointer, let i = screenIndex(containing: pointer, in: screens) { return i }
        if let i = screens.firstIndex(where: { reservedStrip(of: $0)?.edge == prefs.orientation }) { return i }
        if let i = screens.firstIndex(where: { reservedStrip(of: $0) != nil }) { return i }
        return 0
    }

    /// Dock edge on a screen: from the reserved strip when visible, else from the preferences.
    static func edge(of screen: ScreenBox, prefs: DockPrefs) -> DockEdge {
        reservedStrip(of: screen)?.edge ?? prefs.orientation
    }

    /// Thickness of the Dock strip. With autohide the strip is not reserved, so it is estimated.
    static func dockThickness(of screen: ScreenBox, edge: DockEdge, prefs: DockPrefs) -> CGFloat {
        if let strip = reservedStrip(of: screen), strip.edge == edge { return strip.thickness }
        return prefs.tileSize + 18
    }

    /// Distance from the screen edge to the closest point the popup may reach.
    static func dockReach(of screen: ScreenBox, edge: DockEdge, prefs: DockPrefs, offset: CGFloat) -> CGFloat {
        dockThickness(of: screen, edge: edge, prefs: prefs) + prefs.magnificationGap + offset
    }

    /// True when the point lies on the Dock strip (including room for magnified icons).
    static func isOverDock(_ point: CGPoint, screen: ScreenBox, edge: DockEdge, prefs: DockPrefs) -> Bool {
        let reach = dockThickness(of: screen, edge: edge, prefs: prefs) + prefs.magnificationGap + 4
        let f = screen.frame
        guard f.insetBy(dx: -1, dy: -1).contains(point) else { return false }
        switch edge {
        case .bottom: return point.y <= f.minY + reach
        case .left: return point.x <= f.minX + reach
        case .right: return point.x >= f.maxX - reach
        }
    }

    /// Largest popup that fits on a screen for a placement, leaving the Dock and margins free.
    static func maxPopupSize(screens: [ScreenBox], placement: PopupPlacement, anchor: CGPoint?, prefs: DockPrefs, offset: CGFloat) -> CGSize {
        guard !screens.isEmpty else { return CGSize(width: 800, height: 600) }
        let i = dockScreenIndex(screens: screens, pointer: anchor, prefs: prefs)
        let screen = screens[i]
        var area = screen.visibleFrame
        if placement == .aboveTile || placement == .dockCenter {
            let edge = edge(of: screen, prefs: prefs)
            area = areaBeside(screen: screen, edge: edge, prefs: prefs, offset: offset)
        }
        return CGSize(width: max(120, area.width - 2 * margin), height: max(120, area.height - 2 * margin))
    }

    /// The part of the visible frame that does not overlap the Dock (and its magnification).
    static func areaBeside(screen: ScreenBox, edge: DockEdge, prefs: DockPrefs, offset: CGFloat) -> CGRect {
        let reach = dockReach(of: screen, edge: edge, prefs: prefs, offset: offset)
        var area = screen.visibleFrame
        let f = screen.frame
        switch edge {
        case .bottom:
            let minY = max(area.minY, f.minY + reach)
            area = CGRect(x: area.minX, y: minY, width: area.width, height: area.maxY - minY)
        case .left:
            let minX = max(area.minX, f.minX + reach)
            area = CGRect(x: minX, y: area.minY, width: area.maxX - minX, height: area.height)
        case .right:
            let maxX = min(area.maxX, f.maxX - reach)
            area = CGRect(x: area.minX, y: area.minY, width: maxX - area.minX, height: area.height)
        }
        return area
    }

    /// Frame for a popup of `size`.
    /// - anchor: pointer position at the click or hotkey, global Cocoa coordinates.
    /// - offset: user gap between Dock and popup (`AppSettings.popoverOffset`).
    static func place(size: CGSize, placement: PopupPlacement, anchor: CGPoint?, screens: [ScreenBox], prefs: DockPrefs, offset: CGFloat) -> PopupPlacementResult {
        guard !screens.isEmpty else {
            return PopupPlacementResult(frame: CGRect(origin: .zero, size: size), screenIndex: 0, edge: nil, rise: CGVector(dx: 0, dy: 1))
        }
        let index = dockScreenIndex(screens: screens, pointer: anchor, prefs: prefs)
        let screen = screens[index]
        let edge = edge(of: screen, prefs: prefs)
        var mode = placement
        // A click that did not come from the Dock (URL, menu) has nothing to sit above.
        if mode == .aboveTile, anchor.map({ !isOverDock($0, screen: screen, edge: edge, prefs: prefs) }) ?? true {
            mode = .dockCenter
        }
        if mode == .mouse, anchor == nil { mode = .center }

        let f = screen.frame, v = screen.visibleFrame
        var origin = CGPoint.zero
        var attached: DockEdge?
        var rise = CGVector(dx: 0, dy: 1)

        switch mode {
        case .aboveTile, .dockCenter:
            attached = edge
            let reach = dockReach(of: screen, edge: edge, prefs: prefs, offset: offset)
            let along: CGPoint = (mode == .aboveTile ? anchor : nil) ?? CGPoint(x: v.midX, y: v.midY)
            switch edge {
            case .bottom:
                origin = CGPoint(x: along.x - size.width / 2, y: f.minY + reach)
                rise = CGVector(dx: 0, dy: 1)
            case .left:
                origin = CGPoint(x: f.minX + reach, y: along.y - size.height / 2)
                rise = CGVector(dx: 1, dy: 0)
            case .right:
                origin = CGPoint(x: f.maxX - reach - size.width, y: along.y - size.height / 2)
                rise = CGVector(dx: -1, dy: 0)
            }
        case .mouse:
            let p = anchor!
            origin = CGPoint(x: p.x - size.width / 2, y: p.y - size.height / 2)
        case .center:
            // A little above the middle reads as centered.
            origin = CGPoint(x: v.midX - size.width / 2, y: v.midY - size.height / 2 + v.height * 0.05)
        }

        var bounds = v
        if let attached { bounds = areaBeside(screen: screen, edge: attached, prefs: prefs, offset: offset) }
        let frame = clamp(CGRect(origin: origin, size: size), into: bounds, margin: margin)
        return PopupPlacementResult(frame: frame, screenIndex: index, edge: attached, rise: rise)
    }

    /// Moves (and if needed shrinks) a rect so it lies fully inside `bounds` minus a margin.
    /// The Dock side wins: a popup taller than the room keeps its bottom edge.
    static func clamp(_ rect: CGRect, into bounds: CGRect, margin: CGFloat) -> CGRect {
        let b = bounds.insetBy(dx: margin, dy: margin)
        guard b.width > 0, b.height > 0 else { return rect }
        var r = rect
        r.size.width = min(r.width, b.width)
        r.size.height = min(r.height, b.height)
        r.origin.x = min(max(r.minX, b.minX), b.maxX - r.width)
        r.origin.y = min(max(r.minY, b.minY), b.maxY - r.height)
        r.origin.x = r.origin.x.rounded(.down)
        r.origin.y = r.origin.y.rounded(.down)
        return r
    }

    /// Start frame of the open animation: shifted back toward the Dock by `distance`.
    static func animationStart(for frame: CGRect, rise: CGVector, distance: CGFloat) -> CGRect {
        frame.offsetBy(dx: -rise.dx * distance, dy: -rise.dy * distance)
    }
}
