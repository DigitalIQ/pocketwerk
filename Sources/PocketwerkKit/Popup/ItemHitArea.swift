import AppKit
import SwiftUI

/// Mouse handling for one popup cell in AppKit: hover, press, click with modifiers,
/// right-click menu, and a real drag session (into Finder and other apps, reorder, drag out to remove).
struct ItemHitArea: NSViewRepresentable {
    var onHover: (Bool) -> Void
    var onPress: (Bool) -> Void
    var onClick: (NSEvent.ModifierFlags) -> Void
    var menu: () -> NSMenu?
    /// URL and image to drag, nil = not draggable.
    var dragPayload: () -> (url: URL, image: NSImage)?
    var onDragStart: () -> Void = {}
    /// Screen point where the drag ended, the operation the target accepted, and whether it ended outside the popup.
    var onDragEnd: (_ point: NSPoint, _ operation: NSDragOperation, _ outside: Bool) -> Void = { _, _, _ in }
    /// Dragging out of the popup removes the item.
    var removableByDragOut = false

    func makeNSView(context: Context) -> ItemHitView {
        let v = ItemHitView()
        v.config = self
        return v
    }

    func updateNSView(_ nsView: ItemHitView, context: Context) {
        nsView.config = self
    }
}

final class ItemHitView: NSView, NSDraggingSource {
    var config: ItemHitArea?
    private var downEvent: NSEvent?
    private var dragging = false
    private var tracking: NSTrackingArea?
    private var outside = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t)
        tracking = t
    }

    override func mouseEntered(with event: NSEvent) { config?.onHover(true) }
    override func mouseExited(with event: NSEvent) { config?.onHover(false) }

    override func mouseDown(with event: NSEvent) {
        downEvent = event
        dragging = false
        config?.onPress(true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down = downEvent, !dragging else { return }
        let a = down.locationInWindow, b = event.locationInWindow
        guard hypot(b.x - a.x, b.y - a.y) > 4, let payload = config?.dragPayload() else { return }
        dragging = true
        outside = false
        config?.onPress(false)
        config?.onDragStart()
        let item = NSDraggingItem(pasteboardWriter: payload.url as NSURL)
        let side = min(bounds.width, bounds.height, payload.image.size.width + 8)
        let frame = NSRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
        item.setDraggingFrame(frame, contents: payload.image)
        let session = beginDraggingSession(with: [item], event: down, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { downEvent = nil }
        config?.onPress(false)
        guard !dragging, downEvent != nil else { return }
        let local = convert(event.locationInWindow, from: nil)
        guard bounds.contains(local) else { return }
        config?.onClick(event.modifierFlags.intersection(.deviceIndependentFlagsMask))
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        config?.onPress(false)
        return config?.menu()
    }

    // MARK: NSDraggingSource

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? [.move, .copy, .generic] : [.copy, .link, .generic]
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        guard config?.removableByDragOut == true, let window else { return }
        let isOut = !window.frame.insetBy(dx: -8, dy: -8).contains(screenPoint)
        if isOut != outside {
            outside = isOut
            session.animatesToStartingPositionsOnCancelOrFail = !isOut
            (isOut ? NSCursor.disappearingItem : NSCursor.arrow).set()
        }
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        dragging = false
        downEvent = nil
        let isOut = window.map { !$0.frame.insetBy(dx: -8, dy: -8).contains(screenPoint) } ?? false
        if outside { NSCursor.arrow.set() }
        outside = false
        config?.onDragEnd(screenPoint, operation, isOut)
    }
}

/// Small puff where an item was dragged out and removed.
enum PoofEffect {
    static func show(at point: NSPoint) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let size: CGFloat = 44
        let w = NSPanel(contentRect: NSRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.level = .popUpMenu
        w.ignoresMouseEvents = true
        let image = NSImageView(image: NSImage(systemSymbolName: "smoke.fill", accessibilityDescription: nil) ?? NSImage())
        image.symbolConfiguration = .init(pointSize: 30, weight: .regular)
        image.contentTintColor = .secondaryLabelColor
        image.frame = NSRect(x: 0, y: 0, width: size, height: size)
        w.contentView = image
        w.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            w.animator().alphaValue = 0
            w.animator().setFrame(w.frame.insetBy(dx: -10, dy: -10), display: true)
        } completionHandler: {
            MainActor.assumeIsolated { w.orderOut(nil) }
        }
    }
}

/// Lets a pinned popup be moved by dragging its header.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class DragView: NSView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {
            if let window, window.isMovable { window.performDrag(with: event) } else { super.mouseDown(with: event) }
        }
    }
}
