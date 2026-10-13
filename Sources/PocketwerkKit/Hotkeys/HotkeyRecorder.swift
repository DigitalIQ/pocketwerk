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

    @State private var recording = false
    @State private var liveModifiers = ""
    @State private var message: String?
    @State private var monitor: Any?
    /// A click that ends recording must not start it again when it lands on the button.
    @State private var stoppedByClickAt = Date.distantPast

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 4) {
                Button(action: toggleRecording) {
                    Text(label)
                        .monospaced()
                        .foregroundStyle(hotkey == nil && !recording ? .secondary : .primary)
                        .frame(minWidth: 110)
                }
                .buttonStyle(.bordered)
                .tint(recording ? .accentColor : nil)
                .accessibilityLabel(Text("Shortcut"))
                .accessibilityValue(Text(hotkey.map(HotkeyCenter.describe) ?? String(localized: "None")))
                .accessibilityHint(Text("Press to record a new shortcut"))

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
        if recording { return liveModifiers.isEmpty ? String(localized: "Type shortcut…") : liveModifiers }
        if let hotkey { return HotkeyCenter.describe(hotkey) }
        return placeholder ?? String(localized: "Record Shortcut")
    }

    private func toggleRecording() {
        if recording { stop(); return }
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
            let candidate = Hotkey(keyCode: code, modifiers: mods)
            if let problem = HotkeyValidator.problem(for: candidate, target: target, in: LibraryStore.shared.library) {
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
