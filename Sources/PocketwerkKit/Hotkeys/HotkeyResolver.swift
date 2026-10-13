import Foundation

/// One key press: key code plus Carbon modifiers.
nonisolated struct HotkeyStep: Hashable, Sendable {
    var keyCode: UInt32
    var modifiers: UInt32
}

nonisolated extension Hotkey {
    /// The first key followed by the follow-up keys of a sequence.
    var steps: [HotkeyStep] {
        [HotkeyStep(keyCode: keyCode, modifiers: modifiers)]
            + (sequence ?? []).map { HotkeyStep(keyCode: $0.keyCode, modifiers: $0.modifiers) }
    }

    var isPlain: Bool { tapCount <= 1 && (sequence?.isEmpty ?? true) }
}

/// Turns raw key presses into actions for multi-press (double, triple) and key sequences
/// (including the leader key). Pure state machine: the caller feeds presses and timeouts.
nonisolated struct HotkeyResolver {
    enum Output: Equatable {
        /// Run this target now.
        case fire(HotkeyTarget)
        /// More presses may follow. Listen for `followUps` until `deadline`, then call `timeout()`.
        case wait(deadline: Date, followUps: [HotkeyStep])
        case nothing
    }

    var bindings: [HotkeyBinding] = []
    /// Maximum gap between presses of a double or triple press.
    var tapWindow: TimeInterval = 0.35
    /// How long to wait for the next key of a sequence.
    var sequenceTimeout: TimeInterval = 1.5

    private(set) var path: [HotkeyStep] = []
    private(set) var taps = 0
    private var lastPress = Date.distantPast
    /// What fires when nothing else follows.
    private var pending: HotkeyTarget?

    init(bindings: [HotkeyBinding] = [], tapWindow: TimeInterval = 0.35, sequenceTimeout: TimeInterval = 1.5) {
        self.bindings = bindings
        self.tapWindow = tapWindow
        self.sequenceTimeout = sequenceTimeout
    }

    var isWaiting: Bool { !path.isEmpty }

    mutating func reset() {
        path = []
        taps = 0
        pending = nil
    }

    mutating func press(_ step: HotkeyStep, at now: Date) -> Output {
        if path.count == 1, step == path[0], now.timeIntervalSince(lastPress) <= tapWindow {
            taps += 1
        } else if !path.isEmpty, continues(path + [step]) {
            path.append(step)
        } else {
            path = [step]
            taps = 1
        }
        lastPress = now

        let candidates = bindings.filter { b in
            let s = b.hotkey.steps
            return s.count >= path.count && Array(s.prefix(path.count)) == path
        }
        let tapsOf: (HotkeyBinding) -> Int = { max(1, $0.hotkey.tapCount) }
        let exact = candidates.first { $0.hotkey.steps.count == path.count && tapsOf($0) == taps }
        let moreTaps = path.count == 1 && candidates.contains { $0.hotkey.steps.count == 1 && tapsOf($0) > taps }
        let longer = candidates.filter { $0.hotkey.steps.count > path.count && tapsOf($0) == taps }

        if !moreTaps && longer.isEmpty {
            reset()
            return exact.map { .fire($0.target) } ?? .nothing
        }
        pending = exact?.target
        var seen = Set<HotkeyStep>()
        let next = longer.map { $0.hotkey.steps[path.count] }.filter { seen.insert($0).inserted }
        let wait = longer.isEmpty ? tapWindow : max(sequenceTimeout, tapWindow)
        return .wait(deadline: now.addingTimeInterval(wait), followUps: next)
    }

    /// Nothing more came: run what matched so far, if anything.
    mutating func timeout() -> HotkeyTarget? {
        let target = pending
        reset()
        return target
    }

    private func continues(_ candidatePath: [HotkeyStep]) -> Bool {
        bindings.contains { b in
            let s = b.hotkey.steps
            return s.count >= candidatePath.count && Array(s.prefix(candidatePath.count)) == candidatePath
                && max(1, b.hotkey.tapCount) == taps
        }
    }
}
