import Foundation

/// Identifiers shared by the main app and the generated Dock launchers.
public enum PWShared {
    public static let mainBundleID = "io.github.digitaliq.pocketwerk"
    /// Each launcher gets `launcherBundleIDPrefix + slotID.uuidString`.
    public static let launcherBundleIDPrefix = "io.github.digitaliq.pocketwerk.slot."
    /// Custom spacer tiles get `spacerBundleIDPrefix + spacerID.uuidString`.
    public static let spacerBundleIDPrefix = "io.github.digitaliq.pocketwerk.spacer."
    public static let urlScheme = "pocketwerk"

    /// Distributed notification a launcher posts when its Dock icon is clicked.
    /// `object` is the slot UUID string. userInfo carries `xKey`/`yKey` (mouse location, Cocoa coords)
    /// and `timeKey` (seconds since 1970). Only plist types.
    public static let openSlotNotification = Notification.Name("io.github.digitaliq.pocketwerk.openSlot")
    /// Main app posts this when a slot's icon changed. `object` = slot (or spacer) UUID string.
    /// The new icon is the PNG at `iconURL(id:)`.
    public static let iconChangedNotification = Notification.Name("io.github.digitaliq.pocketwerk.iconChanged")
    /// Main app posts this before it rebuilds or deletes a launcher. `object` = UUID string. The launcher quits.
    public static let launcherQuitNotification = Notification.Name("io.github.digitaliq.pocketwerk.launcherQuit")

    public static let xKey = "x"
    public static let yKey = "y"
    public static let timeKey = "t"

    /// Info.plist key inside a launcher bundle that holds the slot UUID.
    public static let slotInfoKey = "PWSlotID"
    /// Info.plist key inside a launcher bundle that holds the main app path (fallback for launching it).
    public static let mainAppPathInfoKey = "PWMainAppPath"
    /// Info.plist key with the template build the launcher was made from. A different value triggers a rebuild.
    public static let buildIDInfoKey = "PWBuildID"
    /// Info.plist key: "slot" (popup launcher) or "spacer" (custom spacer tile).
    public static let kindInfoKey = "PWKind"
    /// Info.plist key with the data folder, written only for development runs ($POCKETWERK_DATA_DIR).
    public static let dataDirInfoKey = "PWDataDir"

    /// Command line argument the main app passes when it starts a launcher itself (no popup on launch).
    public static let quietLaunchArgument = "--quiet"

    /// Bump when the launcher binary or its Info.plist layout changes in a way that needs a rebuild.
    public static let launcherFormat = 2

    /// ~/Library/Application Support/Pocketwerk, or $POCKETWERK_DATA_DIR (or the launcher's PWDataDir).
    public static func dataFolder(bundle: Bundle = .main) -> URL {
        if let env = ProcessInfo.processInfo.environment["POCKETWERK_DATA_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        if let dir = bundle.object(forInfoDictionaryKey: dataDirInfoKey) as? String, !dir.isEmpty {
            return URL(fileURLWithPath: dir, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pocketwerk", isDirectory: true)
    }

    /// Plain folder (not TCC gated) with one PNG per launcher icon.
    public static func iconsFolder(bundle: Bundle = .main) -> URL {
        dataFolder(bundle: bundle).appendingPathComponent("Icons", isDirectory: true)
    }

    public static func iconURL(id: String, bundle: Bundle = .main) -> URL {
        iconsFolder(bundle: bundle).appendingPathComponent("\(id).png")
    }

    public static func libraryURL(bundle: Bundle = .main) -> URL {
        dataFolder(bundle: bundle).appendingPathComponent("library.json")
    }

    /// `pocketwerk://open?slot=<uuid>`
    public static func openURL(slotID: String) -> URL {
        openURL(slotID: slotID, at: nil)
    }

    /// `pocketwerk://open?slot=<uuid>&x=..&y=..`
    public static func openURL(slotID: String, at point: CGPoint?) -> URL {
        var items = [URLQueryItem(name: "slot", value: slotID)]
        if let point {
            items.append(URLQueryItem(name: xKey, value: String(format: "%.1f", point.x)))
            items.append(URLQueryItem(name: yKey, value: String(format: "%.1f", point.y)))
        }
        return url(host: "open", items)
    }

    /// `pocketwerk://add?slot=<uuid>&url=<file url>&url=...` (files dropped on a launcher tile).
    public static func addURL(slotID: String, urls: [URL]) -> URL {
        url(host: "add", [URLQueryItem(name: "slot", value: slotID)] + urls.map { URLQueryItem(name: "url", value: $0.absoluteString) })
    }

    public static func url(host: String, _ items: [URLQueryItem]) -> URL {
        var c = URLComponents()
        c.scheme = urlScheme
        c.host = host
        // Encode values strictly so "&", "=", "+" and "#" inside a value never split the query.
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~/:")
        let enc = { (s: String) in s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s }
        if !items.isEmpty {
            c.percentEncodedQuery = items.map { "\(enc($0.name))=\(enc($0.value ?? ""))" }.joined(separator: "&")
        }
        return c.url!
    }
}
