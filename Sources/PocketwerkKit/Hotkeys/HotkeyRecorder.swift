import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Click, then press a key combination. Esc cancels, Delete clears. All global hotkeys are paused
/// while recording, so an existing combo is recorded instead of fired. Conflicts are refused with a message.
struct HotkeyRecorder: View {
    @Binding var hotkey: Hotkey?
    /// The target being edited; its own combo does not count as a conflict.
    var target: HotkeyTarget?
    /// Shown in grey when no hotkey is set, e.g. the automatic "⌥⇧3".
    var placeholder: String?
    /// Offer double/triple press and follow-up keys.
    var allowsAdvanced = true

    @State private var recording = false
    @State private var liveModifiers = ""
    @State private var message: String?
    @State private var monitor: Any?
    /// A click that ends recording must not start it again when it lands on the button.
    @State private var stoppedByClickAt = Date.distantPast
    /// Recording the next key of a sequence instead of a new hotkey.
    @State private var followUp = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 4) {
                Button(action: toggleRecording) {
                    Text(label)
                        .foregroundStyle(hotkey == nil && !recording ? .secondary : .primary)
                        .frame(minWidth: 110)
                }
                .buttonStyle(.bordered)
                .tint(recording ? .accentColor : nil)
                .accessibilityLabel(Text("Shortcut"))
                .accessibilityValue(Text(hotkey.map(HotkeyCenter.describe) ?? String(localized: "None")))
                .accessibilityHint(Text("Press to record a new shortcut"))

                if let current = hotkey, !recording, allowsAdvanced {
                    Menu {
                        Picker("Press", selection: Binding(get: { max(1, current.tapCount) }, set: { setTaps($0) })) {
                            Text("Once").tag(1)
                            Text("Twice").tag(2)
                            Text("Three Times").tag(3)
                        }
                        Divider()
                        Button("Add Follow-up Key…") { followUp = true; start() }
                            .disabled((current.sequence?.count ?? 0) >= 3)
                        if !(current.sequence ?? []).isEmpty {
                            Button("Remove Follow-up Keys") { var h = current; h.sequence = nil; hotkey = h }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Double press or key sequence")
                    .accessibilityLabel(Text("Shortcut options"))
                }
                if hotkey != nil && !recording {
                    Button {
                        hotkey = nil
                        message = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear shortcut")
                    .accessibilityLabel(Text("Clear shortcut"))
                }
            }
            if let message {
                Text(message).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
        }
        .onDisappear { stop() }
    }

    private var label: String {
        if recording && followUp, let hotkey {
            return HotkeyCenter.describe(hotkey) + " " + (liveModifiers.isEmpty ? "…" : liveModifiers)
        }
        if recording { return liveModifiers.isEmpty ? String(localized: "Type shortcut…") : liveModifiers }
        if let hotkey { return HotkeyCenter.describe(hotkey) }
        return placeholder ?? String(localized: "Record Shortcut")
    }

    private func setTaps(_ n: Int) {
        guard var h = hotkey else { return }
        h.tapCount = n
        if let problem = HotkeyValidator.problem(for: h, target: target, in: LibraryStore.shared.library, firstKeyChecked: true) {
            message = problem
            return
        }
        message = nil
        hotkey = h
    }

    private func toggleRecording() {
        if recording { stop(); return }
        followUp = false
        if Date().timeIntervalSince(stoppedByClickAt) < 0.5 { return }
        start()
    }

    private func start() {
        guard !recording else { return }
        recording = true
        message = nil
        liveModifiers = ""
        HotkeyCenter.shared.pause()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown]) { event in
            let swallow = MainActor.assumeIsolated { handle(event) }
            return swallow ? nil : event
        }
    }

    private func stop() {
        guard recording else { return }
        recording = false
        followUp = false
        liveModifiers = ""
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        HotkeyCenter.shared.resume()
    }

    /// Returns true to swallow the event.
    private func handle(_ event: NSEvent) -> Bool {
        switch event.type {
        case .flagsChanged:
            liveModifiers = HotkeyFormat.modifierSymbols(HotkeyFormat.carbonModifiers(from: event.modifierFlags))
            return true
        case .leftMouseDown, .rightMouseDown:
            // A click anywhere ends recording; the click itself still goes through.
            stop()
            stoppedByClickAt = Date()
            return false
        case .keyDown:
            let code = UInt32(event.keyCode)
            let mods = HotkeyFormat.carbonModifiers(from: event.modifierFlags)
            if mods == 0 && code == UInt32(kVK_Escape) { stop(); return true }
            if mods == 0 && (code == UInt32(kVK_Delete) || code == UInt32(kVK_ForwardDelete)) {
                hotkey = nil
                message = nil
                stop()
                return true
            }
            if mods == 0 && code == UInt32(kVK_Tab) { stop(); return false }
            var candidate = Hotkey(keyCode: code, modifiers: mods)
            if followUp, var base = hotkey {
                base.sequence = (base.sequence ?? []) + [candidate]
                candidate = base
            }
            if let problem = HotkeyValidator.problem(for: candidate, target: target, in: LibraryStore.shared.library,
                                                     firstKeyChecked: followUp) {
                message = "\(HotkeyCenter.describe(candidate)): \(problem)"
                NSSound.beep()
                return true
            }
            message = nil
            hotkey = candidate
            stop()
            return true
        default:
            return false
        }
    }
}
