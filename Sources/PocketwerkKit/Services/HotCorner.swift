import AppKit

/// Screen corner that opens all groups when the pointer rests in it. 0 top-left, 1 top-right,
/// 2 bottom-left, 3 bottom-right (`AppSettings.hotCorner`).
nonisolated enum HotCornerGeometry {
    /// True when `point` lies within `tolerance` points of corner `corner` of `frame` (Cocoa coordinates).
    static func isInCorner(_ point: CGPoint, corner: Int, frame: CGRect, tolerance: CGFloat = 3) -> Bool {
        let left = point.x <= frame.minX + tolerance
        let right = point.x >= frame.maxX - 1 - tolerance
        let top = point.y >= frame.maxY - 1 - tolerance
        let bottom = point.y <= frame.minY + tolerance
        switch corner {
        case 0: return left && top
        case 1: return right && top
        case 2: return left && bottom
        case 3: return right && bottom
        default: return false
        }
    }

    static func title(_ corner: Int?) -> String {
        switch corner {
        case 0: String(localized: "Top left")
        case 1: String(localized: "Top right")
        case 2: String(localized: "Bottom left")
        case 3: String(localized: "Bottom right")
        default: String(localized: "Off")
        }
    }
}

/// Watches the pointer position a few times per second, only while a corner is set.
/// Needs no permission: it reads `NSEvent.mouseLocation`, it does not monitor input events.
final class HotCornerWatcher {
    static let shared = HotCornerWatcher()
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    private var enteredAt: Date?
    /// After firing, the pointer must leave the corner before it can fire again.
    private var armed = true
    private let dwell: TimeInterval = 0.25

    func start() {
        update()
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: .libraryDidChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { HotCornerWatcher.shared.update() }
        }
    }

    private func update() {
        let wanted = LibraryStore.shared.settings.hotCorner != nil
        if wanted, timer == nil {
            let t = Timer(timeInterval: 0.12, repeats: true) { _ in
                MainActor.assumeIsolated { HotCornerWatcher.shared.tick() }
            }
            t.tolerance = 0.05
            RunLoop.main.add(t, forMode: .common)
            timer = t
        } else if !wanted, let t = timer {
            t.invalidate()
            timer = nil
        }
    }

    private func tick() {
        guard let corner = LibraryStore.shared.settings.hotCorner else { return }
        let p = NSEvent.mouseLocation
        let inside = NSScreen.screens.contains { HotCornerGeometry.isInCorner(p, corner: corner, frame: $0.frame) }
        guard inside, NSEvent.pressedMouseButtons == 0 else {
            enteredAt = nil
            if !inside { armed = true }
            return
        }
        guard armed else { return }
        if let start = enteredAt {
            if Date().timeIntervalSince(start) >= dwell {
                armed = false
                enteredAt = nil
                if !PopupController.shared.isVisible { PopupController.shared.toggleAll(source: .hotkey) }
            }
        } else {
            enteredAt = Date()
        }
    }
}
