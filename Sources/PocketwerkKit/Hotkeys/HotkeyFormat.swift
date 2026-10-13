import AppKit
import Carbon.HIToolbox

/// Turns Carbon key codes and modifiers into readable text, e.g. "⌃⌥P".
nonisolated enum HotkeyFormat {
    static let command = UInt32(cmdKey)
    static let shift = UInt32(shiftKey)
    static let option = UInt32(optionKey)
    static let control = UInt32(controlKey)

    /// Modifier symbols in the order macOS menus use: ⌃⌥⇧⌘.
    static func modifierSymbols(_ modifiers: UInt32) -> String {
        var s = ""
        if modifiers & control != 0 { s += "⌃" }
        if modifiers & option != 0 { s += "⌥" }
        if modifiers & shift != 0 { s += "⇧" }
        if modifiers & command != 0 { s += "⌘" }
        return s
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= command }
        if flags.contains(.shift) { m |= shift }
        if flags.contains(.option) { m |= option }
        if flags.contains(.control) { m |= control }
        return m
    }

    static func eventModifiers(from carbon: UInt32) -> NSEvent.ModifierFlags {
        var f: NSEvent.ModifierFlags = []
        if carbon & command != 0 { f.insert(.command) }
        if carbon & shift != 0 { f.insert(.shift) }
        if carbon & option != 0 { f.insert(.option) }
        if carbon & control != 0 { f.insert(.control) }
        return f
    }

    static let functionKeys: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    /// Keys whose name does not depend on the keyboard layout.
    static let specialKeys: [Int: String] = functionKeys.merging([
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_ANSI_KeypadEnter: "⌤",
        kVK_Help: "Help", kVK_ANSI_KeypadClear: "⌧",
        kVK_ANSI_Keypad0: "Num 0", kVK_ANSI_Keypad1: "Num 1", kVK_ANSI_Keypad2: "Num 2", kVK_ANSI_Keypad3: "Num 3",
        kVK_ANSI_Keypad4: "Num 4", kVK_ANSI_Keypad5: "Num 5", kVK_ANSI_Keypad6: "Num 6", kVK_ANSI_Keypad7: "Num 7",
        kVK_ANSI_Keypad8: "Num 8", kVK_ANSI_Keypad9: "Num 9", kVK_ANSI_KeypadPlus: "Num +",
        kVK_ANSI_KeypadMinus: "Num -", kVK_ANSI_KeypadMultiply: "Num *", kVK_ANSI_KeypadDivide: "Num /",
        kVK_ANSI_KeypadDecimal: "Num .", kVK_ANSI_KeypadEquals: "Num =",
    ]) { a, _ in a }

    /// US layout names, used when the current layout cannot be read.
    static let ansiFallback: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E", kVK_ANSI_F: "F",
        kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R",
        kVK_ANSI_S: "S", kVK_ANSI_T: "T", kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
        kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Backslash: "\\", kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'", kVK_ANSI_Comma: ",",
        kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/", kVK_ANSI_Grave: "`", kVK_ISO_Section: "§",
    ]

    /// Key codes of the digit keys 1...9 (the same on every layout position).
    static let digitKeyCodes: [UInt32] = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                                          kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9].map(UInt32.init)

    static func isFunctionKey(_ keyCode: UInt32) -> Bool { functionKeys[Int(keyCode)] != nil }

    /// Name of a key. `translate` maps a key code to the character of the current layout (nil = unknown).
    static func keyName(_ keyCode: UInt32, translate: (UInt32) -> String?) -> String {
        if let special = specialKeys[Int(keyCode)] { return special }
        if let ch = translate(keyCode), !ch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ch.uppercased()
        }
        return ansiFallback[Int(keyCode)] ?? "Key \(keyCode)"
    }

    static func describe(_ hotkey: Hotkey, translate: (UInt32) -> String?) -> String {
        var s = modifierSymbols(hotkey.modifiers) + keyName(hotkey.keyCode, translate: translate)
        if hotkey.tapCount > 1 { s += " ×\(hotkey.tapCount)" }
        if let seq = hotkey.sequence, !seq.isEmpty {
            s += " " + seq.map { describe($0, translate: translate) }.joined(separator: " ")
        }
        return s
    }

    /// Default group hotkey ⌥⇧1...9 for position 0...8.
    static func numberHotkey(_ index: Int) -> Hotkey? {
        guard digitKeyCodes.indices.contains(index) else { return nil }
        return Hotkey(keyCode: digitKeyCodes[index], modifiers: option | shift)
    }
}

/// Reads characters from the current keyboard layout, so a German layout shows Z, Y and Ö correctly.
enum KeyboardLayout {
    static func character(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { buffer -> OSStatus in
            guard let base = buffer.baseAddress else { return OSStatus(paramErr) }
            return UCKeyTranslate(base.assumingMemoryBound(to: UCKeyboardLayout.self), UInt16(keyCode),
                                  UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                  OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeys, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
