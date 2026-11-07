import AppKit
import SwiftUI

/// The language Pocketwerk shows.
///
/// "Same as macOS" follows the system languages. English and Deutsch write `AppleLanguages` into
/// Pocketwerk's own defaults, the same value that System Settings > General > Language & Region >
/// Applications sets. macOS reads it when an app starts, so a change takes effect after a restart.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case german = "de"

    var id: String { rawValue }

    static let defaultsKey = "AppleLanguages"

    /// Language names stay in their own language, so everyone finds theirs.
    var label: Text {
        switch self {
        case .system: return Text("Same as macOS")
        case .english: return Text(verbatim: "English")
        case .german: return Text(verbatim: "Deutsch")
        }
    }

    /// The choice stored for Pocketwerk alone. The global AppleLanguages of macOS does not count.
    static var current: AppLanguage {
        // Exact lookup in this app's domain for the current user, without the global fallback.
        let value = CFPreferencesCopyValue(defaultsKey as CFString, kCFPreferencesCurrentApplication,
                                           kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard let first = (value as? [String])?.first else { return .system }
        if first.hasPrefix("de") { return .german }
        if first.hasPrefix("en") { return .english }
        return .system
    }

    static func store(_ language: AppLanguage) {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: defaultsKey)
        }
    }

    /// Quits and starts Pocketwerk again. A small shell waits until this process has ended,
    /// then opens the same bundle. The path goes in as an argument, never into the script text.
    static func relaunch() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "while kill -0 \(getpid()) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"",
                       Bundle.main.bundlePath]
        do {
            try p.run()
        } catch {
            Log.app.error("relaunch failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        NSApp.terminate(nil)
    }
}

struct AppLanguagePicker: View {
    @State private var language = AppLanguage.current
    @State private var changed = false

    var body: some View {
        Picker("Language", selection: Binding(get: { language }, set: { new in
            language = new
            AppLanguage.store(new)
            changed = true
        })) {
            ForEach(AppLanguage.allCases) { $0.label.tag($0) }
        }
        if changed {
            HStack {
                Text("Pocketwerk switches the language after a restart.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Restart Now") { AppLanguage.relaunch() }.controlSize(.small)
            }
        }
    }
}
