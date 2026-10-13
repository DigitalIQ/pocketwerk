import AppKit
import Observation
import ServiceManagement

/// "1.2.10", "v1.3", "2.0.0-beta.1". Pre-releases sort before the release with the same numbers.
nonisolated struct SemanticVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    var numbers: [Int]
    var prerelease: String?

    init?(_ text: String) {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.first == "v" || t.first == "V" { t.removeFirst() }
        let parts = t.split(separator: "-", maxSplits: 1).map(String.init)
        guard let core = parts.first, !core.isEmpty else { return nil }
        let nums = core.split(separator: ".").map { Int($0) }
        guard !nums.isEmpty, nums.allSatisfy({ $0 != nil }) else { return nil }
        numbers = nums.compactMap { $0 }
        prerelease = parts.count > 1 ? parts[1] : nil
    }

    var description: String { numbers.map(String.init).joined(separator: ".") + (prerelease.map { "-\($0)" } ?? "") }

    static func < (a: SemanticVersion, b: SemanticVersion) -> Bool {
        let n = max(a.numbers.count, b.numbers.count)
        for i in 0..<n {
            let x = i < a.numbers.count ? a.numbers[i] : 0
            let y = i < b.numbers.count ? b.numbers[i] : 0
            if x != y { return x < y }
        }
        switch (a.prerelease, b.prerelease) {
        case (nil, nil), (nil, _?): return false
        case (_?, nil): return true
        case let (x?, y?): return x.compare(y, options: .numeric) == .orderedAscending
        }
    }

    static func == (a: SemanticVersion, b: SemanticVersion) -> Bool { !(a < b) && !(b < a) }
}

nonisolated struct Release: Equatable, Sendable {
    var version: String
    var url: URL
    var name: String

    /// Parses the GitHub "latest release" JSON. Drafts and pre-releases are ignored.
    static func parse(_ data: Data) -> Release? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let link = (json["html_url"] as? String).flatMap(URL.init(string:)),
              (json["draft"] as? Bool) != true, (json["prerelease"] as? Bool) != true
        else { return nil }
        return Release(version: tag, url: link, name: (json["name"] as? String) ?? tag)
    }

    /// True when `version` is newer than `current` and not skipped.
    static func isNewer(_ version: String, than current: String, skipped: String?) -> Bool {
        guard let new = SemanticVersion(version), let cur = SemanticVersion(current) else { return false }
        if let skipped, let s = SemanticVersion(skipped), s == new { return false }
        return cur < new
    }
}

/// Daily check of the GitHub releases API. No other network traffic, no data sent besides the request.
@Observable
final class UpdateChecker {
    static let shared = UpdateChecker()
    static let feed = URL(string: "https://api.github.com/repos/DigitalIQ/pocketwerk/releases/latest")!
    static let project = URL(string: "https://github.com/DigitalIQ/pocketwerk")!

    /// A newer release, shown as a small notice.
    private(set) var available: Release?
    private(set) var isChecking = false
    private(set) var lastResult: String?
    @ObservationIgnored private var timer: Timer?

    static var currentVersion: String? { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String }

    func startDaily() {
        guard timer == nil else { return }
        checkIfDue()
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            MainActor.assumeIsolated { UpdateChecker.shared.checkIfDue() }
        }
    }

    func checkIfDue() {
        let s = LibraryStore.shared.settings
        guard s.checkForUpdates else { return }
        if let last = s.lastUpdateCheck, Date().timeIntervalSince(last) < 24 * 3600 { return }
        Task { await check() }
    }

    func check() async {
        guard !isChecking else { return }
        guard let current = Self.currentVersion else {
            lastResult = String(localized: "Development build, version unknown.")
            return
        }
        isChecking = true
        defer { isChecking = false }
        var request = URLRequest(url: Self.feed, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            LibraryStore.shared.settings.lastUpdateCheck = Date()
            guard (response as? HTTPURLResponse)?.statusCode == 200, let release = Release.parse(data) else {
                lastResult = String(localized: "No release found.")
                return
            }
            if Release.isNewer(release.version, than: current, skipped: LibraryStore.shared.settings.skippedVersion) {
                available = release
                lastResult = String(localized: "Version \(release.version) is available.")
            } else {
                available = nil
                lastResult = String(localized: "Pocketwerk is up to date.")
            }
        } catch {
            lastResult = String(localized: "Check failed: \(error.localizedDescription)")
        }
    }

    func skipAvailable() {
        guard let available else { return }
        LibraryStore.shared.settings.skippedVersion = available.version
        self.available = nil
    }

    func openAvailable() {
        if let available { NSWorkspace.shared.open(available.url) }
    }
}

/// Launch at login through the system login items. Synced at every launch, because a rebuilt
/// (re-signed) app can drop out of the list.
enum LoginItem {
    static func sync(wanted: Bool) {
        let s = SMAppService.mainApp
        switch (wanted, s.status) {
        case (true, .notRegistered), (true, .notFound): try? s.register()
        case (true, .requiresApproval): break
        case (false, .enabled), (false, .requiresApproval): try? s.unregister()
        default: break
        }
    }

    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
