import AppKit
import SwiftUI

/// Borderless floating panel that takes keyboard input without activating the app.
final class PopupPanel: NSPanel {
    var onResignKey: (() -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        animationBehavior = .none
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        setAccessibilityRole(.popover)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }

    /// Floating window mode: stays above other windows, can be moved, survives focus loss.
    func setPinned(_ pinned: Bool) {
        level = pinned ? .floating : .popUpMenu
        isMovable = pinned
        collectionBehavior = pinned
            ? [.canJoinAllSpaces, .fullScreenAuxiliary]
            : [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }
}

/// One popup window with its model. The controller keeps one reusable session plus pinned ones.
final class PopupSession {
    let panel = PopupPanel()
    let model: PopupModel
    let host: NSHostingView<PopupRootView>
    /// Pointer position the popup was opened at, kept for resizes.
    var anchor: CGPoint?
    var placement: PopupPlacement = .aboveTile
    var placed: PopupPlacementResult?

    init() {
        model = PopupModel(groupIDs: [])
        host = NSHostingView(rootView: PopupRootView(model: model))
        // The controller sets the window size; the hosting view must not push its own.
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
    }
}
