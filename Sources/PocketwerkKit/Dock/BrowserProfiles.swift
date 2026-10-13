import Foundation

/// Browser profiles for the "open browser profile" tile action. Discovery reads each browser's
/// profile list, which macOS may flag as reading another app's data, so it only runs on request.
nonisolated enum BrowserProfiles {
    struct Browser: Hashable, Sendable {
        var bundleID: String
        var name: String
        /// Folder under ~/Library/Application Support.
        var supportPath: String
        var isFirefox = false
    }

    struct Profile: Hashable, Sendable {
        /// What the launch argument needs: the folder name (Chromium) or the profile name (Firefox).
        var id: String
        var name: String
    }

    /// Safari is not here on purpose: it has no command line profile switch.
    static let browsers: [Browser] = [
        Browser(bundleID: "com.google.Chrome", name: "Google Chrome", supportPath: "Google/Chrome"),
        Browser(bundleID: "com.microsoft.edgemac", name: "Microsoft Edge", supportPath: "Microsoft Edge"),
        Browser(bundleID: "com.brave.Browser", name: "Brave", supportPath: "BraveSoftware/Brave-Browser"),
        Browser(bundleID: "com.vivaldi.Vivaldi", name: "Vivaldi", supportPath: "Vivaldi"),
        Browser(bundleID: "company.thebrowser.Browser", name: "Arc", supportPath: "Arc/User Data"),
        Browser(bundleID: "org.mozilla.firefox", name: "Firefox", supportPath: "Firefox", isFirefox: true),
    ]

    static func browser(_ bundleID: String?) -> Browser? {
        browsers.first { $0.bundleID == bundleID }
    }

    /// Launch arguments that open the given profile.
    static func arguments(bundleID: String, profile: String) -> [String] {
        browser(bundleID)?.isFirefox == true ? ["-P", profile] : ["--profile-directory=\(profile)"]
    }

    /// Reads the profile list of a browser. Empty when the browser has never run.
    static func discover(_ browser: Browser, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [Profile] {
        let base = home.appendingPathComponent("Library/Application Support").appendingPathComponent(browser.supportPath)
        if browser.isFirefox {
            guard let text = try? String(contentsOf: base.appendingPathComponent("profiles.ini"), encoding: .utf8) else { return [] }
            return parseFirefoxINI(text)
        }
        guard let data = try? Data(contentsOf: base.appendingPathComponent("Local State")) else { return [] }
        return parseChromiumLocalState(data)
    }

    /// `profile.info_cache` of a Chromium "Local State" file, sorted by name.
    static func parseChromiumLocalState(_ data: Data) -> [Profile] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cache = (root["profile"] as? [String: Any])?["info_cache"] as? [String: Any] else { return [] }
        return cache.map { key, value in
            Profile(id: key, name: ((value as? [String: Any])?["name"] as? String) ?? key)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// `Name=` entries of the `[ProfileN]` sections in Firefox's profiles.ini.
    static func parseFirefoxINI(_ text: String) -> [Profile] {
        var out: [Profile] = []
        var inProfile = false
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                inProfile = line.hasPrefix("[Profile")
            } else if inProfile, line.hasPrefix("Name=") {
                let name = String(line.dropFirst(5))
                out.append(Profile(id: name, name: name))
            }
        }
        return out
    }
}
