import AppKit
import SwiftUI

/// Where a request to show a popup came from. Decides the placement setting.
enum PopupSource {
    /// Click on a Dock tile (anchor = pointer at the click).
    case dock
    /// Global hotkey: uses `AppSettings.hotkeyPlacement`.
    case hotkey
    /// Menu bar icon: opens below the pointer.
    case menuBar
}

/// Shows the popup for a Dock slot or a list of groups, near the Dock icon.
/// The window is created once and reused, so it appears within one frame of the click.
final class PopupController {
    static let shared = PopupController()

    private var session: PopupSession?
    /// Popped-out popups that stay until closed.
    private var pinnedSessions: [PopupSession] = []
    private(set) var currentSlotID: UUID?
    private(set) var isVisible = false
    private var currentKey: String?

    private var monitors: [Any] = []
    private var globalMonitor: Any?
    private var lastHide: (key: String?, time: Date) = (nil, .distantPast)
    private var suppressCloseUntil = Date.distantPast
    private var autoCloseSuspended = false
    private var swipe = SwipeTracker()
    private var prepared = false

    // MARK: Public API

    /// Creates the window, starts the icon cache and running-app tracking. Cheap; heavy work is deferred.
    func prepare() {
        guard !prepared else { return }
        prepared = true
        _ = activeSession()
        PopupIconCache.shared.start()
        RunningApps.shared.start()
        NotificationCenter.default.addObserver(forName: .libraryDidChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { PopupController.shared.libraryChanged() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { PopupController.shared.screensChanged() }
        }
    }

    /// Called when a launcher's Dock icon is clicked or a slot hotkey fires.
    func toggle(slotID: UUID, anchor: CGPoint? = nil, source: PopupSource? = nil) {
        let groups = LibraryStore.shared.groups(for: slotID).map(\.id)
        toggle(groupIDs: groups, slotID: slotID, anchor: anchor, source: source)
    }

    /// Every group, swipeable. Used by the main app Dock icon, the menu bar, and the main hotkey.
    func toggleAll(anchor: CGPoint? = nil, source: PopupSource? = nil) {
        let groups = LibraryStore.shared.library.carouselGroups.map(\.id)
        toggle(groupIDs: groups, slotID: nil, anchor: anchor, source: source)
    }

    func toggle(groupIDs: [UUID], slotID: UUID?, anchor: CGPoint? = nil, source: PopupSource? = nil) {
        let key = Self.key(groupIDs: groupIDs, slotID: slotID)
        if isVisible, currentKey == key { hide(); return }
        // The click on the Dock tile already closed this popup as an outside click: keep it closed.
        if !isVisible, lastHide.key == key, Date().timeIntervalSince(lastHide.time) < 0.45 { return }
        show(groupIDs: groupIDs, slotID: slotID, anchor: anchor, source: source)
    }

    /// anchor: screen point (Cocoa coordinates) to place the popup near; nil = mouse location.
    func show(groupIDs: [UUID], slotID: UUID?, anchor: CGPoint? = nil, source: PopupSource? = nil) {
        prepare()
        let store = LibraryStore.shared
        let ids = groupIDs.filter { store.group($0) != nil }
        guard !ids.isEmpty else {
            NSSound.beep()
            return
        }
        let s = activeSession()
        let settings = store.settings
        let pointer = anchor ?? NSEvent.mouseLocation
        let placement: PopupPlacement
        switch source {
        case .hotkey: placement = settings.hotkeyPlacement
        case .menuBar: placement = .mouse
        case .dock, nil: placement = settings.placement
        }
        s.anchor = pointer
        s.placement = placement

        let m = s.model
        m.groupIDs = ids
        m.slotID = slotID
        m.position = CarouselPosition(group: 0, page: 0)
        m.folderStack = []
        m.selection = nil
        m.picked = []
        m.query = ""
        m.renaming = nil
        m.openAllArmed = false
        m.pinned = false
        m.dropIndex = nil
        m.modifiers = NSEvent.modifierFlags
        let prefs = DockPrefs.current()
        m.maxSize = DockGeometry.maxPopupSize(screens: ScreenBox.all, placement: placement, anchor: pointer, prefs: prefs, offset: settings.popoverOffset)

        let size = m.desiredSize()
        let result = DockGeometry.place(size: size, placement: placement, anchor: pointer, screens: ScreenBox.all, prefs: prefs, offset: settings.popoverOffset)
        s.placed = result
        m.panelSize = result.frame.size
        applyAppearance(s)

        let panel = s.panel
        panel.setPinned(false)
        // Lay out the SwiftUI content before the window is visible.
        panel.setFrame(result.frame, display: false)
        s.host.layoutSubtreeIfNeeded()

        currentKey = Self.key(groupIDs: groupIDs, slotID: slotID)
        currentSlotID = slotID
        isVisible = true
        m.isVisible = true
        installMonitors()
        animateIn(s, to: result)
        panel.invalidateShadow()
    }

    func hide() {
        hide(byOutsideClick: false)
    }

    // MARK: Sessions

    private func activeSession() -> PopupSession {
        if let session { return session }
        let s = PopupSession()
        wire(s)
        session = s
        return s
    }

    private func wire(_ s: PopupSession) {
        s.panel.onResignKey = { [weak self, weak s] in
            guard let self, let s else { return }
            self.resignedKey(s)
        }
        s.model.actions = PopupActions(
            close: { [weak self, weak s] in
                guard let self, let s else { return }
                self.close(s)
            },
            resize: { [weak self, weak s] in
                guard let self, let s else { return }
                self.resize(s)
            },
            quickLook: { [weak s] item in
                guard let s else { return }
                QuickLookPanel.shared.toggle(item, beside: s.panel)
            },
            togglePin: { [weak self, weak s] in
                guard let self, let s else { return }
                self.togglePin(s)
            },
            willLaunch: { [weak self] in
                self?.suppressCloseUntil = Date().addingTimeInterval(1.5)
            },
            didLaunch: { [weak self, weak s] in
                guard let self, let s else { return }
                if LibraryStore.shared.settings.closeAfterOpen, !s.model.pinned { self.close(s) }
            },
            windowFrame: { [weak s] in s?.panel.frame },
            suspendAutoClose: { [weak self] on in self?.autoCloseSuspended = on }
        )
    }

    private func close(_ s: PopupSession) {
        if s === session {
            hide()
        } else {
            // A pinned popup.
            s.model.isVisible = false
            s.panel.orderOut(nil)
            pinnedSessions.removeAll { $0 === s }
            if QuickLookPanel.shared.owner === s.panel { QuickLookPanel.shared.close() }
        }
    }

    /// Pop out: the current popup becomes a floating window; the next popup gets a fresh window.
    private func togglePin(_ s: PopupSession) {
        if s.model.pinned {
            s.model.pinned = false
            close(s)
            return
        }
        s.model.pinned = true
        s.panel.setPinned(true)
        guard s === session else { return }
        pinnedSessions.append(s)
        session = nil
        isVisible = false
        currentKey = nil
        currentSlotID = nil
        removeMonitors()
        installKeyMonitors()
    }

    private func hide(byOutsideClick: Bool) {
        guard let s = session, isVisible else { return }
        lastHide = (byOutsideClick ? currentKey : nil, Date())
        isVisible = false
        currentKey = nil
        currentSlotID = nil
        s.model.isVisible = false
        s.model.renaming = nil
        removeMonitors()
        if !pinnedSessions.isEmpty { installKeyMonitors() }
        if QuickLookPanel.shared.owner === s.panel { QuickLookPanel.shared.close() }
        s.panel.orderOut(nil)
    }

    private func resignedKey(_ s: PopupSession) {
        guard s === session, isVisible, !s.model.pinned, !autoCloseSuspended else { return }
        if Date() < suppressCloseUntil { return }
        // Menus and the Quick Look panel do not count as leaving the popup.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isVisible, !self.autoCloseSuspended else { return }
            if NSApp.keyWindow === QuickLookPanel.shared.panel { return }
            if Date() < self.suppressCloseUntil { return }
            self.hide()
        }
    }

    // MARK: Geometry and animation

    private func resize(_ s: PopupSession) {
        guard s.panel.isVisible else { return }
        let size = s.model.desiredSize()
        guard size != s.panel.frame.size else { return }
        let frame: CGRect
        if s.model.pinned {
            // Pinned windows grow from their top left corner and stay on their screen.
            var f = s.panel.frame
            f.origin.y += f.height - size.height
            f.size = size
            let screen = s.panel.screen?.visibleFrame ?? f
            frame = DockGeometry.clamp(f, into: screen, margin: DockGeometry.margin)
        } else {
            let settings = LibraryStore.shared.settings
            frame = DockGeometry.place(size: size, placement: s.placement, anchor: s.anchor, screens: ScreenBox.all,
                                       prefs: DockPrefs.current(), offset: settings.popoverOffset).frame
        }
        s.model.panelSize = frame.size
        let duration = Self.animationDuration(LibraryStore.shared.settings.animationSpeed) * 0.9
        if duration > 0 {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = duration
                ctx.timingFunction = Self.easeOut
                s.panel.animator().setFrame(frame, display: true)
            } completionHandler: {
                MainActor.assumeIsolated { s.panel.invalidateShadow() }
            }
        } else {
            s.panel.setFrame(frame, display: true)
            s.panel.invalidateShadow()
        }
        if QuickLookPanel.shared.owner === s.panel { QuickLookPanel.shared.reposition() }
    }

    /// 200 ms fade with an 8 pt rise toward the screen center. None under Reduce Motion or with speed off.
    private func animateIn(_ s: PopupSession, to result: PopupPlacementResult) {
        let panel = s.panel
        let duration = Self.animationDuration(LibraryStore.shared.settings.animationSpeed)
        if duration == 0 {
            panel.alphaValue = 1
            panel.setFrame(result.frame, display: true)
            panel.orderFrontRegardless()
            panel.makeKey()
            return
        }
        panel.alphaValue = 0
        panel.setFrame(DockGeometry.animationStart(for: result.frame, rise: result.rise, distance: 8), display: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = Self.easeOut
            panel.animator().alphaValue = 1
            panel.animator().setFrame(result.frame, display: true)
        }
    }

    /// cubic-bezier(0.16, 1, 0.3, 1)
    static let easeOut = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)

    static func animationDuration(_ speed: AnimationSpeed) -> Double {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return 0 }
        switch speed {
        case .slow: return 0.32
        case .medium: return 0.2
        case .fast: return 0.12
        case .off: return 0
        }
    }

    private func applyAppearance(_ s: PopupSession) {
        guard let group = s.model.currentGroup else { return }
        switch LibraryStore.shared.popupStyle(of: group).appearance {
        case .system: s.panel.appearance = nil
        case .light: s.panel.appearance = NSAppearance(named: .aqua)
        case .dark: s.panel.appearance = NSAppearance(named: .darkAqua)
        }
        s.panel.hasShadow = LibraryStore.shared.popupStyle(of: group).shadow
    }

    private func libraryChanged() {
        for s in [session].compactMap({ $0 }) + pinnedSessions where s.panel.isVisible {
            // Groups that were deleted disappear from open popups.
            let store = LibraryStore.shared
            let ids = s.model.groupIDs.filter { store.group($0) != nil }
            if ids.isEmpty { close(s); continue }
            if ids != s.model.groupIDs {
                s.model.groupIDs = ids
                s.model.position.group = min(s.model.position.group, ids.count - 1)
            }
            applyAppearance(s)
            resize(s)
        }
    }

    private func screensChanged() {
        if isVisible { hide() }
    }

    static func key(groupIDs: [UUID], slotID: UUID?) -> String {
        slotID.map { "slot:\($0)" } ?? "groups:" + groupIDs.map(\.uuidString).joined(separator: ",")
    }

    // MARK: Event monitors

    private func installMonitors() {
        removeMonitors()
        installKeyMonitors()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { _ in
            MainActor.assumeIsolated { PopupController.shared.outsideClick() }
        }
    }

    private func installKeyMonitors() {
        guard monitors.isEmpty else { return }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.keyDown], handler: { event in
            let handled = MainActor.assumeIsolated { PopupController.shared.handleKey(event) }
            return handled ? nil : event
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel], handler: { event in
            let handled = MainActor.assumeIsolated { PopupController.shared.handleScroll(event) }
            return handled ? nil : event
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged], handler: { event in
            MainActor.assumeIsolated { PopupController.shared.handleFlags(event) }
            return event
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown], handler: { event in
            MainActor.assumeIsolated { PopupController.shared.localClick(event) }
            return event
        }) { monitors.append(m) }
    }

    private func removeMonitors() {
        for m in monitors { NSEvent.removeMonitor(m) }
        monitors = []
        if let g = globalMonitor { NSEvent.removeMonitor(g) }
        globalMonitor = nil
    }

    private func outsideClick() {
        guard isVisible, let s = session, !s.model.pinned, !autoCloseSuspended else { return }
        let p = NSEvent.mouseLocation
        if s.panel.frame.contains(p) { return }
        if QuickLookPanel.shared.isVisible, QuickLookPanel.shared.panel.frame.contains(p) { return }
        hide(byOutsideClick: true)
    }

    /// Clicks into another window of this app close the popup too.
    private func localClick(_ event: NSEvent) {
        guard isVisible, let s = session, !s.model.pinned, !autoCloseSuspended else { return }
        guard let w = event.window, w !== s.panel, w !== QuickLookPanel.shared.panel else { return }
        if w is NSPanel, w.className.contains("Menu") { return }
        hide(byOutsideClick: true)
    }

    /// The session whose window gets this event.
    private func session(for event: NSEvent) -> PopupSession? {
        let all = [session].compactMap { $0 } + pinnedSessions
        return all.first { $0.panel === event.window && $0.panel.isVisible }
    }

    private func handleFlags(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        for s in [session].compactMap({ $0 }) + pinnedSessions where s.model.modifiers != flags {
            s.model.modifiers = flags
        }
    }

    private func handleScroll(_ event: NSEvent) -> Bool {
        guard let s = session(for: event), let group = s.model.currentGroup else { return false }
        let m = s.model
        let metrics = m.metrics(for: group)
        let canPage = metrics.pageCount > 1 || m.groupIDs.count > 1
        guard canPage else { return false }
        if let step = swipe.feed(event, contentScrolls: metrics.scrolls) {
            withPopupAnimation { m.step(step) }
            return true
        }
        return swipe.isHorizontalGesture
    }

    // MARK: Keyboard

    private func handleKey(_ event: NSEvent) -> Bool {
        guard let s = session(for: event) else { return false }
        let m = s.model
        guard let group = m.currentGroup else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd = flags.contains(.command)
        let chars = event.charactersIgnoringModifiers ?? ""

        // Inline rename owns the keyboard, except Escape.
        if m.renaming != nil {
            if event.keyCode == 53 { m.renaming = nil; return true }
            return false
        }

        let items = m.shownItems(of: group)
        let metrics = m.metrics(for: group)
        let range = metrics.pageRange(m.position.page, itemCount: m.cellCount(of: group))

        switch event.keyCode {
        case 53: // Escape: preview, search, folder, selection, popup
            if QuickLookPanel.shared.isVisible { QuickLookPanel.shared.close() }
            else if !m.query.isEmpty { m.query = ""; m.selection = nil; m.actions.resize() }
            else if m.isInFolder { withPopupAnimation { m.leaveFolder() } }
            else if !m.picked.isEmpty { m.picked = []; m.actions.resize() }
            else if !m.pinned { close(s) }
            return true
        case 36, 76: // Return
            if cmd { m.openAll(in: group); return true }
            if !m.picked.isEmpty { m.openPicked(in: group); return true }
            if let sel = m.selection {
                if sel < items.count { m.activate(items[sel], in: group) }
                else if let folder = m.folderStack.last { NSWorkspace.shared.open(folder.url) }
            } else if items.count == 1 || (!m.query.isEmpty && !items.isEmpty) {
                m.activate(items[0], in: group)
            }
            return true
        case 49 where m.query.isEmpty: // Space: Quick Look
            if let sel = m.selection, sel < items.count { m.actions.quickLook(items[sel]) }
            return true
        case 123, 124, 125, 126: // arrows
            let dir: MoveDirection = [123: .left, 124: .right, 125: .down, 126: .up][event.keyCode]!
            if cmd || flags.contains(.option) {
                if dir == .left || dir == .right { withPopupAnimation { m.step(dir == .left ? -1 : 1) } }
                return true
            }
            let count = m.cellCount(of: group)
            // Leaving the page sideways moves to the next page or group.
            if let sel = m.selection, (dir == .right && sel == range.upperBound - 1 && sel < count - 1)
                || (dir == .left && sel == range.lowerBound && sel > 0) {
                withPopupAnimation { m.showPage(m.position.page + (dir == .right ? 1 : -1)) }
                m.selection = dir == .right ? sel + 1 : sel - 1
                return true
            }
            if m.selection == nil, (dir == .left || dir == .right), m.groupIDs.count > 1 || metrics.pageCount > 1, count == 0 {
                withPopupAnimation { m.step(dir == .left ? -1 : 1) }
                return true
            }
            let current = m.selection.map { $0 } ?? nil
            var next = SelectionMath.move(current, dir, count: count, columns: metrics.columns)
            if current == nil { next = range.lowerBound < count ? range.lowerBound : nil }
            m.selection = next
            if let n = next, !range.contains(n) { withPopupAnimation { m.showPage(metrics.page(of: n)) } }
            return true
        case 48: // Tab: next or previous group
            withPopupAnimation {
                if m.groupIDs.count > 1 {
                    let i = (m.position.group + (flags.contains(.shift) ? -1 : 1) + m.groupIDs.count) % m.groupIDs.count
                    m.showGroup(at: i)
                }
            }
            return true
        case 51: // Delete
            if cmd {
                if let sel = m.selection, sel < items.count, m.isEditable(in: group) {
                    LibraryStore.shared.removeItem(items[sel].id, from: LibraryStore.shared.owningGroupID(of: items[sel].id, fallback: group.id))
                }
            } else if !m.query.isEmpty {
                m.query.removeLast()
                m.selection = m.query.isEmpty ? nil : 0
                m.actions.resize()
            } else if m.isInFolder {
                withPopupAnimation { m.leaveFolder() }
            }
            return true
        default:
            break
        }

        if cmd {
            switch chars {
            case "1", "2", "3", "4", "5", "6", "7", "8", "9":
                withPopupAnimation { m.showGroup(at: Int(chars)! - 1) }
                return true
            case "+", "=":
                LibraryStore.shared.adjustIconSize(of: group.id, by: 8)
                return true
            case "-":
                LibraryStore.shared.adjustIconSize(of: group.id, by: -8)
                return true
            case "w":
                close(s)
                return true
            case "a":
                m.picked = Set(items.map(\.url))
                m.actions.resize()
                return true
            case "o":
                if !m.picked.isEmpty { m.openPicked(in: group) } else { m.openAll(in: group) }
                return true
            case "y":
                if let sel = m.selection, sel < items.count { m.actions.quickLook(items[sel]) }
                return true
            default:
                return false
            }
        }
        if flags.contains(.control) { return false }

        // Type to search.
        if let typed = event.characters, !typed.isEmpty,
           typed.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && $0.value < 0xF700 }) {
            m.query += typed
            m.selection = 0
            m.position.page = 0
            m.actions.resize()
            return true
        }
        return false
    }
}

/// Runs a state change with the popup's slide animation (a plain fade under Reduce Motion).
@MainActor func withPopupAnimation(_ change: () -> Void) {
    let duration = PopupController.animationDuration(LibraryStore.shared.settings.animationSpeed)
    if duration == 0 {
        change()
    } else {
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: duration * 1.2), change)
    }
}

/// Turns trackpad swipes and mouse wheel ticks into page steps.
/// Trackpad: the direction is decided at gesture start, one step per gesture after 40 pt, momentum ignored.
/// Mouse wheel: one step per tick burst (0.35 s), vertical ticks only when the content does not scroll.
struct SwipeTracker {
    private var accumulated: CGFloat = 0
    private var decided: Bool?
    private var fired = false
    private var lastWheel = Date.distantPast
    private(set) var isHorizontalGesture = false

    mutating func feed(_ event: NSEvent, contentScrolls: Bool) -> Int? {
        if event.hasPreciseScrollingDeltas {
            if !event.momentumPhase.isEmpty { return nil }
            if event.phase.contains(.began) || event.phase.contains(.mayBegin) {
                accumulated = 0; decided = nil; fired = false; isHorizontalGesture = false
            }
            let dx = event.scrollingDeltaX, dy = event.scrollingDeltaY
            if decided == nil, dx != 0 || dy != 0 {
                decided = abs(dx) > abs(dy) * 1.2
                isHorizontalGesture = decided == true
            }
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                defer { decided = nil; isHorizontalGesture = false }
                return nil
            }
            guard decided == true, !fired else { return nil }
            // Finger movement, independent of the natural scrolling setting.
            let finger = event.isDirectionInvertedFromDevice ? dx : -dx
            accumulated += finger
            if abs(accumulated) > 40 {
                fired = true
                return accumulated < 0 ? 1 : -1
            }
            return nil
        }
        // Mouse wheel.
        let dx = event.scrollingDeltaX, dy = event.scrollingDeltaY
        let horizontal = abs(dx) > abs(dy)
        if !horizontal && contentScrolls { return nil }
        let delta = horizontal ? dx : dy
        guard delta != 0, Date().timeIntervalSince(lastWheel) > 0.35 else { return nil }
        lastWheel = Date()
        return delta < 0 ? 1 : -1
    }
}
