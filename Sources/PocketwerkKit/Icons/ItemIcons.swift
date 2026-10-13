import AppKit

extension Notification.Name {
    /// Posted when an item icon changed (a favicon arrived). Views showing item icons redraw.
    static let itemIconsDidChange = Notification.Name("PocketwerkItemIconsDidChange")
}

/// Icons of single items: app, file and folder icons from the system, favicons for links. Cached.
final class ItemIconCache {
    static let shared = ItemIconCache()

    private let cache = NSCache<NSString, NSImage>()
    private let sized = NSCache<NSString, NSImage>()
    /// Bumps when cached icons change, so composed icons re-render.
    private(set) var generation = 0

    init() {
        cache.countLimit = 400
        sized.countLimit = 600
    }

    private func key(_ item: DockItem) -> String { "\(item.kind.rawValue)|\(item.bundleID ?? "")|\(item.url.absoluteString)" }

    /// The shared full-size icon of an item. Do not change its size; use `icon(for:size:)` for a sized copy.
    func baseIcon(for item: DockItem) -> NSImage {
        let k = key(item) as NSString
        if let hit = cache.object(forKey: k) { return hit }
        let img = makeIcon(item)
        cache.setObject(img, forKey: k)
        return img
    }

    /// A bitmap of the icon at `size` points (2x pixels). Bitmaps draw fast and look the same everywhere.
    func icon(for item: DockItem, size: CGFloat) -> NSImage {
        let k = "\(key(item))|\(Int(size.rounded()))" as NSString
        if let hit = sized.object(forKey: k) { return hit }
        let base = baseIcon(for: item)
        let px = Int(min(1024, max(1, (size * 2).rounded())))
        let image: NSImage
        if let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                               space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            ctx.interpolationQuality = .high
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            base.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            image = ctx.makeImage().map { NSImage(cgImage: $0, size: NSSize(width: size, height: size)) } ?? base
        } else {
            image = base
        }
        sized.setObject(image, forKey: k)
        return image
    }

    func invalidate() {
        cache.removeAllObjects()
        sized.removeAllObjects()
        generation += 1
    }

    private func makeIcon(_ item: DockItem) -> NSImage {
        let ws = NSWorkspace.shared
        switch item.kind {
        case .app:
            if FileManager.default.fileExists(atPath: item.url.path) { return ws.icon(forFile: item.url.resolvingSymlinksInPath().path) } // Safari in /Applications is a link since macOS 26
            if let id = item.bundleID, let url = ws.urlForApplication(withBundleIdentifier: id) { return ws.icon(forFile: url.path) }
            return ws.icon(for: .application)
        case .file:
            return item.exists ? ws.icon(forFile: item.url.path) : ws.icon(for: .data)
        case .folder:
            return item.exists ? ws.icon(forFile: item.url.path) : ws.icon(for: .folder)
        case .link:
            let favicon = item.url.host(percentEncoded: false).flatMap { FaviconStore.shared.image(forHost: $0) }
            if favicon == nil, let host = item.url.host(percentEncoded: false), ["http", "https"].contains(item.url.scheme ?? "") {
                FaviconStore.shared.fetchIfNeeded(host: host) { [weak self] in
                    self?.invalidate()
                    NotificationCenter.default.post(name: .itemIconsDidChange, object: nil)
                }
            }
            return Self.linkTile(favicon: favicon)
        }
    }

    /// Links look like app icons: a light squircle with the site's favicon, or a globe.
    static func linkTile(favicon: NSImage?) -> NSImage {
        let px: CGFloat = 256
        return NSImage(size: NSSize(width: px, height: px), flipped: false) { rect in
            let art = rect.insetBy(dx: px * 0.1, dy: px * 0.1)
            let path = NSBezierPath(roundedRect: art, xRadius: art.width * 0.2237, yRadius: art.width * 0.2237)
            NSGraphicsContext.current?.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
            shadow.shadowOffset = NSSize(width: 0, height: -px * 0.01)
            shadow.shadowBlurRadius = px * 0.025
            shadow.set()
            if favicon != nil {
                NSGradient(starting: .white, ending: NSColor(white: 0.93, alpha: 1))?.draw(in: path, angle: -90)
            } else {
                NSGradient(starting: NSColor(srgbRed: 0.33, green: 0.62, blue: 1, alpha: 1),
                           ending: NSColor(srgbRed: 0.1, green: 0.38, blue: 0.9, alpha: 1))?.draw(in: path, angle: -90)
            }
            NSGraphicsContext.current?.restoreGraphicsState()
            if let favicon {
                favicon.draw(in: art.insetBy(dx: art.width * 0.22, dy: art.width * 0.22), from: .zero, operation: .sourceOver, fraction: 1)
            } else if let globe = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: art.width * 0.5, weight: .medium).applying(.init(paletteColors: [.white]))) {
                let s = globe.size
                globe.draw(in: NSRect(x: art.midX - s.width / 2, y: art.midY - s.height / 2, width: s.width, height: s.height))
            }
            return true
        }
    }
}

/// Favicons for link items. Each host is fetched once from its own domain and kept on disk under
/// the data folder. This is the only network access of the Icons module.
final class FaviconStore {
    static let shared = FaviconStore()

    /// Tests turn this off.
    static var fetchingEnabled = true
    /// nil = `<data dir>/Favicons`. Tests point this at a temporary folder.
    var directoryOverride: URL?

    private var memory: [String: NSImage] = [:]
    private var inFlight: Set<String> = []
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.httpAdditionalHeaders = ["User-Agent": "Pocketwerk"]
        return URLSession(configuration: config)
    }()

    var directory: URL {
        let dir = directoryOverride ?? LibraryStore.directory.appendingPathComponent("Favicons", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fileURL(_ host: String, ext: String) -> URL {
        let safe = host.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" }
        return directory.appendingPathComponent("\(safe).\(ext)")
    }

    func image(forHost host: String) -> NSImage? {
        if let hit = memory[host] { return hit }
        guard let img = NSImage(contentsOf: fileURL(host, ext: "png")) else { return nil }
        memory[host] = img
        return img
    }

    /// Fetches the favicon once. Failures are remembered for a week so a dead site is not asked again and again.
    func fetchIfNeeded(host: String, completion: @escaping () -> Void) {
        guard Self.fetchingEnabled, !inFlight.contains(host) else { return }
        let marker = fileURL(host, ext: "none")
        if let date = (try? FileManager.default.attributesOfItem(atPath: marker.path))?[.modificationDate] as? Date,
           Date().timeIntervalSince(date) < 7 * 86_400 { return }
        inFlight.insert(host)
        Task { [session] in
            var found: NSImage?
            for path in ["/apple-touch-icon.png", "/favicon.ico"] {
                guard let url = URL(string: "https://\(host)\(path)"),
                      let (data, response) = try? await session.data(from: url),
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      let img = NSImage(data: data), img.isValid, img.size.width > 0 else { continue }
                found = img
                break
            }
            inFlight.remove(host)
            if let found, let png = Self.normalizedPNG(found) {
                try? png.write(to: fileURL(host, ext: "png"), options: .atomic)
                memory[host] = NSImage(data: png)
                completion()
            } else {
                try? Data().write(to: marker)
            }
        }
    }

    /// Draws the best representation into a 128 px square PNG.
    static func normalizedPNG(_ image: NSImage) -> Data? {
        let px = 128
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}
