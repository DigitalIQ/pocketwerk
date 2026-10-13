import AppKit
import Carbon.HIToolbox
import Observation

/// Carbon calls this for every registered hotkey. Must be a plain C function, so it is a
/// nonisolated global function that hops to the main actor.
nonisolated private func pocketwerkHotkeyHandler(_ next: EventHandlerCallRef?, _ event: EventRef?,
                                                 _ user: UnsafeMutableRawPointer?) -> OSStatus {
    var hk = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                   nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
    guard status == noErr else { return status }
    let id = hk.id
    DispatchQueue.main.async { MainActor.assumeIsolated { HotkeyCenter.shared.fire(id) } }
    return noErr
}

/// Global hotkeys via Carbon RegisterEventHotKey (no Accessibility permission needed, works in full screen).
/// Registers: settings.mainHotkey (all groups), the next-profile hotkey, each group's hotkey (or ⌥⇧1...9),
/// each slot's hotkey and each profile's hotkey. Re-syncs on every `.libraryDidChange`.
@Observable
final class HotkeyCenter {
    static let shared = HotkeyCenter()

    /// Targets whose hotkey could not be registered because another app holds it.
    private(set) var failed: Set<HotkeyTarget> = []
    /// Hotkeys currently active (for badges).
    private(set) var active: [HotkeyBinding] = []

    @ObservationIgnored private let signature: OSType = 0x5057_484B // "PWHK"
    @ObservationIgnored private var handler: EventHandlerRef?
    @ObservationIgnored private var refs: [UInt32: EventHotKeyRef] = [:]
    @ObservationIgnored private var targets: [UInt32: HotkeyTarget] = [:]
    @ObservationIgnored private var registered: [HotkeyBinding] = []
    @ObservationIgnored private var pauseCount = 0
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var store: LibraryStore { LibraryStore.shared }

    /// Registers all hotkeys and re-syncs on every `.libraryDidChange`.
    func start() {
        installHandlerIfNeeded()
        sync()
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: .libraryDidChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { HotkeyCenter.shared.sync() }
        }
    }

    /// Human readable form, e.g. "⌃⌥P", using the current keyboard layout.
    static func describe(_ hotkey: Hotkey) -> String {
        HotkeyFormat.describe(hotkey) { KeyboardLayout.character(for: $0) }
    }

    // MARK: Pause while recording

    /// Unregisters everything, so pressing an existing combo while recording is recorded instead of fired.
    func pause() {
        pauseCount += 1
        if pauseCount == 1 { unregisterAll() }
    }

    func resume() {
        pauseCount = max(0, pauseCount - 1)
        if pauseCount == 0 { sync(force: true) }
    }

    var isPaused: Bool { pauseCount > 0 }

    // MARK: Registration

    /// Re-registers when the wanted set changed. Unregistering everything first prevents stale
    /// ("shadow") hotkeys after renames or reassignments.
    func sync(force: Bool = false) {
        guard pauseCount == 0 else { return }
        let wanted = HotkeyPlan.bindings(store.library)
        guard force || wanted != registered else { return }
        unregisterAll()
        installHandlerIfNeeded()
        var failures = Set<HotkeyTarget>()
        var ok: [HotkeyBinding] = []
        for (i, b) in wanted.enumerated() {
            let id = UInt32(i + 1)
            var ref: EventHotKeyRef?
            let err = RegisterEventHotKey(b.hotkey.keyCode, b.hotkey.modifiers, EventHotKeyID(signature: signature, id: id),
                                          GetEventDispatcherTarget(), 0, &ref)
            if err == noErr, let ref {
                refs[id] = ref
                targets[id] = b.target
                ok.append(b)
            } else if !b.isDefault {
                failures.insert(b.target)
            }
        }
        registered = wanted
        if failed != failures { failed = failures }
        if active != ok { active = ok }
    }

    private func unregisterAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs = [:]
        targets = [:]
        registered = []
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), pocketwerkHotkeyHandler, 1, &spec, nil, &handler)
    }

    func fire(_ id: UInt32) {
        guard pauseCount == 0, let target = targets[id] else { return }
        perform(target)
    }

    func perform(_ target: HotkeyTarget) {
        switch target {
        case .main:
            PopupController.shared.toggle(groupIDs: store.library.carouselGroups.map(\.id), slotID: nil)
        case .nextProfile:
            if let id = HotkeyPlan.nextProfile(store.library) { DockProfiles.shared.apply(id) }
        case .group(let id):
            PopupController.shared.toggle(groupIDs: [id], slotID: nil)
        case .slot(let id):
            PopupController.shared.toggle(slotID: id)
        case .profile(let id):
            DockProfiles.shared.apply(id)
        case .saveToActiveProfile:
            DockProfiles.shared.saveCurrentToActive()
        }
    }
}

// MARK: - Checks against macOS and the app menu

enum HotkeyValidator {
    /// A message when the combo cannot be used, nil when it is fine.
    static func problem(for hotkey: Hotkey, target: HotkeyTarget?, in lib: Library) -> String? {
        let mods = hotkey.modifiers
        let strong = HotkeyFormat.command | HotkeyFormat.option | HotkeyFormat.control
        if mods & strong == 0 && !HotkeyFormat.isFunctionKey(hotkey.keyCode) {
            return String(localized: "Add ⌘, ⌥ or ⌃ to the key.")
        }
        if let owner = HotkeyPlan.owner(of: hotkey, in: lib, excluding: target) {
            return String(localized: "Already used by \(HotkeyPlan.name(of: owner, in: lib)).")
        }
        if isSystemShortcut(hotkey) {
            return String(localized: "macOS already uses this shortcut.")
        }
        if let title = menuItemTitle(for: hotkey) {
            return String(localized: "The menu command “\(title)” uses this shortcut.")
        }
        return nil
    }

    /// Enabled system shortcuts (Spotlight, screenshots, Mission Control, ...).
    static func isSystemShortcut(_ hotkey: Hotkey) -> Bool {
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr, let array = unmanaged?.takeRetainedValue() as? [[String: Any]] else {
            return false
        }
        let relevant = HotkeyFormat.command | HotkeyFormat.option | HotkeyFormat.control | HotkeyFormat.shift
        for entry in array {
            guard (entry[kHISymbolicHotKeyEnabled as String] as? Bool) == true,
                  let code = (entry[kHISymbolicHotKeyCode as String] as? NSNumber)?.uint32Value,
                  let mods = (entry[kHISymbolicHotKeyModifiers as String] as? NSNumber)?.uint32Value
            else { continue }
            if code == hotkey.keyCode && (mods & relevant) == (hotkey.modifiers & relevant) { return true }
        }
        return false
    }

    /// Title of a Pocketwerk menu item with the same key equivalent.
    static func menuItemTitle(for hotkey: Hotkey) -> String? {
        guard let main = NSApp?.mainMenu,
              let ch = KeyboardLayout.character(for: hotkey.keyCode)?.lowercased(), !ch.isEmpty else { return nil }
        let flags = HotkeyFormat.eventModifiers(from: hotkey.modifiers)
        func search(_ menu: NSMenu) -> String? {
            for item in menu.items {
                if let sub = item.submenu, let hit = search(sub) { return hit }
                guard !item.keyEquivalent.isEmpty else { continue }
                var itemFlags = item.keyEquivalentModifierMask.intersection([.command, .option, .control, .shift])
                var key = item.keyEquivalent
                if key != key.lowercased() { itemFlags.insert(.shift); key = key.lowercased() }
                if key == ch && itemFlags == flags { return item.title }
            }
            return nil
        }
        return search(main)
    }
}
