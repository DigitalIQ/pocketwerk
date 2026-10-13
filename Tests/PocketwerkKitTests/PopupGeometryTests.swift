import CoreGraphics
import Testing
@testable import PocketwerkKit

@Suite struct PopupGeometryTests {
    // 1440x900 display, 25 pt menu bar.
    static let full = CGRect(x: 0, y: 0, width: 1440, height: 900)
    static let bottomDock = ScreenBox(frame: full, visibleFrame: CGRect(x: 0, y: 60, width: 1440, height: 815))
    static let leftDock = ScreenBox(frame: full, visibleFrame: CGRect(x: 70, y: 0, width: 1370, height: 875))
    static let rightDock = ScreenBox(frame: full, visibleFrame: CGRect(x: 0, y: 0, width: 1370, height: 875))
    static let hiddenDock = ScreenBox(frame: full, visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875))
    static let size = CGSize(width: 400, height: 300)
    static let prefs = DockPrefs(orientation: .bottom, tileSize: 48, largeSize: 64, magnification: false, autohide: false)

    func place(_ screens: [ScreenBox], anchor: CGPoint?, placement: PopupPlacement = .aboveTile, prefs: DockPrefs = prefs, size: CGSize = size, offset: CGFloat = 10) -> PopupPlacementResult {
        DockGeometry.place(size: size, placement: placement, anchor: anchor, screens: screens, prefs: prefs, offset: offset)
    }

    @Test func reservedStripFindsEdge() {
        #expect(DockGeometry.reservedStrip(of: Self.bottomDock)?.edge == .bottom)
        #expect(DockGeometry.reservedStrip(of: Self.bottomDock)?.thickness == 60)
        #expect(DockGeometry.reservedStrip(of: Self.leftDock)?.edge == .left)
        #expect(DockGeometry.reservedStrip(of: Self.rightDock)?.edge == .right)
        #expect(DockGeometry.reservedStrip(of: Self.hiddenDock) == nil)
        // A few points of inset are no Dock.
        let tiny = ScreenBox(frame: Self.full, visibleFrame: CGRect(x: 0, y: 4, width: 1440, height: 871))
        #expect(DockGeometry.reservedStrip(of: tiny) == nil)
    }

    @Test func bottomDockAboveTile() {
        let r = place([Self.bottomDock], anchor: CGPoint(x: 300, y: 20))
        #expect(r.edge == .bottom)
        #expect(r.frame == CGRect(x: 100, y: 70, width: 400, height: 300))
        #expect(r.rise == CGVector(dx: 0, dy: 1))
    }

    @Test func magnificationAddsGap() {
        var prefs = Self.prefs
        prefs.magnification = true
        prefs.largeSize = 128
        let r = place([Self.bottomDock], anchor: CGPoint(x: 300, y: 20), prefs: prefs)
        #expect(r.frame.minY == 150) // strip 60 + magnification 80 + offset 10
        // Magnification smaller than the tile size adds nothing.
        prefs.largeSize = 32
        #expect(place([Self.bottomDock], anchor: CGPoint(x: 300, y: 20), prefs: prefs).frame.minY == 70)
    }

    @Test func leftDock() {
        var prefs = Self.prefs
        prefs.orientation = .left
        let r = place([Self.leftDock], anchor: CGPoint(x: 30, y: 400), prefs: prefs)
        #expect(r.edge == .left)
        #expect(r.frame == CGRect(x: 80, y: 250, width: 400, height: 300))
        #expect(r.rise == CGVector(dx: 1, dy: 0))
    }

    @Test func rightDock() {
        var prefs = Self.prefs
        prefs.orientation = .right
        let r = place([Self.rightDock], anchor: CGPoint(x: 1420, y: 400), prefs: prefs)
        #expect(r.edge == .right)
        #expect(r.frame == CGRect(x: 1440 - 70 - 10 - 400, y: 250, width: 400, height: 300))
        #expect(r.rise == CGVector(dx: -1, dy: 0))
    }

    @Test func edgeComesFromStripBeforePrefs() {
        // Preferences still say bottom, the screen shows a left strip.
        let r = place([Self.leftDock], anchor: CGPoint(x: 30, y: 400))
        #expect(r.edge == .left)
    }

    @Test func autohideEstimatesThickness() {
        var prefs = Self.prefs
        prefs.autohide = true
        let r = place([Self.hiddenDock], anchor: CGPoint(x: 300, y: 10), prefs: prefs)
        #expect(r.frame.minY == 76) // tile 48 + 18 + offset 10
    }

    @Test func staysOnScreenAtTheEdges() {
        let right = place([Self.bottomDock], anchor: CGPoint(x: 1430, y: 20))
        #expect(right.frame.maxX == 1440 - DockGeometry.margin)
        let left = place([Self.bottomDock], anchor: CGPoint(x: 5, y: 20))
        #expect(left.frame.minX == DockGeometry.margin)
        let tall = place([Self.bottomDock], anchor: CGPoint(x: 700, y: 20), size: CGSize(width: 400, height: 2000))
        #expect(tall.frame.minY == 70)
        #expect(tall.frame.maxY <= 875 - DockGeometry.margin)
        let wide = place([Self.bottomDock], anchor: CGPoint(x: 700, y: 20), size: CGSize(width: 3000, height: 200))
        #expect(wide.frame.width == 1440 - 2 * DockGeometry.margin)
    }

    @Test func dockCenterIgnoresPointerX() {
        let r = place([Self.bottomDock], anchor: CGPoint(x: 100, y: 20), placement: .dockCenter)
        #expect(r.frame.midX == 720)
        #expect(r.frame.minY == 70)
    }

    @Test func aboveTileFallsBackWhenNotOverDock() {
        // Hotkey or URL with the pointer in the middle of the screen.
        let r = place([Self.bottomDock], anchor: CGPoint(x: 100, y: 500))
        #expect(r.frame.midX == 720)
        #expect(r.edge == .bottom)
    }

    @Test func mousePlacementCentersOnPointer() {
        let r = place([Self.bottomDock], anchor: CGPoint(x: 700, y: 500), placement: .mouse, size: CGSize(width: 200, height: 100))
        #expect(r.frame == CGRect(x: 600, y: 450, width: 200, height: 100))
        #expect(r.edge == nil)
        // Near the top the popup is pushed below the menu bar.
        let top = place([Self.bottomDock], anchor: CGPoint(x: 700, y: 895), placement: .mouse, size: CGSize(width: 200, height: 100))
        #expect(top.frame.maxY <= 875 - DockGeometry.margin)
    }

    @Test func centerPlacement() {
        let r = place([Self.bottomDock], anchor: nil, placement: .center, size: CGSize(width: 200, height: 100))
        #expect(r.frame.midX == 720)
        #expect(r.frame.midY > 467)
    }

    @Test func multiScreenUsesPointerScreen() {
        let main = Self.bottomDock
        let second = ScreenBox(frame: CGRect(x: 1440, y: -100, width: 1920, height: 1080),
                               visibleFrame: CGRect(x: 1440, y: -100, width: 1920, height: 1055))
        let r = place([main, second], anchor: CGPoint(x: 2000, y: -90))
        #expect(r.screenIndex == 1)
        #expect(r.frame.minY == -24) // -100 + tile 48 + 18 + offset 10
        #expect(r.frame.midX == 2000)
        // No pointer: the screen that shows the Dock strip.
        #expect(DockGeometry.dockScreenIndex(screens: [second, main], pointer: nil, prefs: Self.prefs) == 1)
    }

    @Test func screenLeftOfMainWithNegativeCoordinates() {
        let main = Self.hiddenDock
        let left = ScreenBox(frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
                             visibleFrame: CGRect(x: -1920, y: 70, width: 1920, height: 985))
        let r = place([main, left], anchor: CGPoint(x: -1000, y: 30))
        #expect(r.screenIndex == 1)
        #expect(r.frame.minY == 80)
        #expect(r.frame.midX == -1000)
        #expect(r.frame.minX >= -1920)
    }

    @Test func pointerOnFarEdgeBelongsToScreen() {
        #expect(DockGeometry.screenIndex(containing: CGPoint(x: 1440, y: 900), in: [Self.bottomDock]) == 0)
        #expect(DockGeometry.screenIndex(containing: CGPoint(x: 3000, y: 900), in: [Self.bottomDock]) == nil)
    }

    @Test func maxSizeLeavesRoomForDock() {
        let m = DockGeometry.maxPopupSize(screens: [Self.bottomDock], placement: .aboveTile, anchor: CGPoint(x: 10, y: 10), prefs: Self.prefs, offset: 10)
        #expect(m.height == 875 - 70 - 2 * DockGeometry.margin)
        #expect(m.width == 1440 - 2 * DockGeometry.margin)
    }

    @Test func animationStartsTowardTheDock() {
        let f = CGRect(x: 100, y: 70, width: 10, height: 10)
        #expect(DockGeometry.animationStart(for: f, rise: CGVector(dx: 0, dy: 1), distance: 8).minY == 62)
        #expect(DockGeometry.animationStart(for: f, rise: CGVector(dx: -1, dy: 0), distance: 8).minX == 108)
    }
}
