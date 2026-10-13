import Foundation

/// What a hotkey does.
nonisolated enum HotkeyTarget: Hashable, Sendable {
    /// All groups (the carousel).
    case main
    case nextProfile
    case group(UUID)
    case slot(UUID)
    case profile(UUID)
    /// Saves the current Dock into the active profile.
    case saveToActiveProfile
}

/// One hotkey that should be registered.
nonisolated struct HotkeyBinding: Hashable, Sendable {
    var target: HotkeyTarget
    var hotkey: Hotkey
    /// True for the automatic ⌥⇧1...9 group keys.
    var isDefault = false
}

/// Pure planning: which hotkeys exist, which collide. No Carbon calls here, so it is testable.
nonisolated enum HotkeyPlan {
    /// Hotkeys compare by key and modifiers only.
    struct Combo: Hashable {
        var keyCode: UInt32
        var modifiers: UInt32
        init(_ h: Hotkey) { keyCode = h.keyCode; modifiers = h.modifiers }
    }

    /// Every hotkey the user set, in a fixed order (main, next profile, groups, slots, profiles).
    static func explicitBindings(_ lib: Library) -> [HotkeyBinding] {
        var out: [HotkeyBinding] = []
        if let h = lib.settings.mainHotkey { out.append(.init(target: .main, hotkey: h)) }
        if let h = lib.settings.nextProfileHotkey { out.append(.init(target: .nextProfile, hotkey: h)) }
        if let h = lib.settings.saveToLastHotkey { out.append(.init(target: .saveToActiveProfile, hotkey: h)) }
        for g in lib.orderedGroups { if let h = g.hotkey { out.append(.init(target: .group(g.id), hotkey: h)) } }
        for s in lib.slots { if let h = s.hotkey { out.append(.init(target: .slot(s.id), hotkey: h)) } }
        for p in lib.profiles { if let h = p.hotkey { out.append(.init(target: .profile(p.id), hotkey: h)) } }
        return out
    }

    /// Automatic ⌥⇧1...9 for the first nine sidebar groups that have no own hotkey.
    /// A default is skipped when the user gave the same combo to something else.
    static func defaultGroupBindings(_ lib: Library) -> [HotkeyBinding] {
        guard lib.settings.numberHotkeys else { return [] }
        let taken = Set(explicitBindings(lib).map { Combo($0.hotkey) })
        var out: [HotkeyBinding] = []
        for (i, g) in lib.orderedGroups.prefix(9).enumerated() where g.hotkey == nil {
            guard let h = HotkeyFormat.numberHotkey(i), !taken.contains(Combo(h)) else { continue }
            out.append(.init(target: .group(g.id), hotkey: h, isDefault: true))
        }
        return out
    }

    /// Everything to register. When two targets share a combo, only the first is kept.
    static func bindings(_ lib: Library) -> [HotkeyBinding] {
        var seen = Set<Combo>()
        return (explicitBindings(lib) + defaultGroupBindings(lib)).filter { seen.insert(Combo($0.hotkey)).inserted }
    }

    /// The hotkey a group answers to: its own, or its ⌥⇧ number default.
    static func effectiveHotkey(forGroup id: UUID, in lib: Library) -> HotkeyBinding? {
        bindings(lib).first { $0.target == .group(id) }
    }

    /// Combos used by more than one target.
    static func conflicts(_ lib: Library) -> [(hotkey: Hotkey, targets: [HotkeyTarget])] {
        var byCombo: [Combo: [HotkeyBinding]] = [:]
        var order: [Combo] = []
        for b in explicitBindings(lib) {
            let c = Combo(b.hotkey)
            if byCombo[c] == nil { order.append(c) }
            byCombo[c, default: []].append(b)
        }
        return order.compactMap { c in
            guard let list = byCombo[c], list.count > 1 else { return nil }
            return (list[0].hotkey, list.map(\.target))
        }
    }

    /// The other target the user already gave this combo, if any. Automatic ⌥⇧ number keys
    /// do not count: a user hotkey simply replaces them.
    static func owner(of hotkey: Hotkey, in lib: Library, excluding target: HotkeyTarget?) -> HotkeyTarget? {
        let c = Combo(hotkey)
        return explicitBindings(lib).first { Combo($0.hotkey) == c && $0.target != target }?.target
    }

    /// Short readable name of a target, e.g. "Group “Work”".
    static func name(of target: HotkeyTarget, in lib: Library) -> String {
        switch target {
        case .main: return String(localized: "All groups")
        case .nextProfile: return String(localized: "Next profile")
        case .group(let id): return String(localized: "Group “\(lib.group(id)?.name ?? "?")”")
        case .slot(let id): return String(localized: "Dock icon “\(lib.slot(id)?.name ?? "?")”")
        case .profile(let id):
            return String(localized: "Profile “\(lib.profiles.first { $0.id == id }?.name ?? "?")”")
        case .saveToActiveProfile: return String(localized: "Save Dock into active profile")
        }
    }

    /// Profile after the last applied one, skipping profiles excluded from cycling.
    static func nextProfile(_ lib: Library) -> UUID? {
        let cycle = lib.profiles.filter { !$0.excludedFromCycle }
        guard !cycle.isEmpty else { return nil }
        guard let last = lib.settings.lastAppliedProfileID,
              let i = cycle.firstIndex(where: { $0.id == last }) else { return cycle[0].id }
        return cycle[(i + 1) % cycle.count].id
    }
}
