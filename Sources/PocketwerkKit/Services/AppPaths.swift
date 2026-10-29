import Foundation

/// Paths of apps as people know them. Since macOS 13, Safari and a few other system apps live in a
/// cryptex on the Preboot volume, and `/Applications` holds a link to each. The system reports the
/// cryptex path (`/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app`); Finder shows
/// the link (`/Applications/Safari.app`). Both open the same app.
nonisolated enum AppPaths {
    static let cryptexApps = "/Cryptexes/App/System/Applications/"

    /// The `/Applications` link for an app in the cryptex, when that link points to the same app.
    /// Any other URL comes back unchanged. Touches the disk only for cryptex paths.
    static func visible(_ url: URL, resolve: (URL) -> URL = { $0.resolvingSymlinksInPath() }) -> URL {
        guard url.isFileURL, url.path.contains(cryptexApps) else { return url }
        let link = URL(fileURLWithPath: "/Applications", isDirectory: true)
            .appendingPathComponent(url.lastPathComponent, isDirectory: true)
        return resolve(link).path == resolve(url).path ? link : url
    }
}
