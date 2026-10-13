import AppKit
import Observation
import QuickLookThumbnailing

/// Rasterized item icons, so opening the popup never waits for the disk.
/// Wraps `IconRenderer.icon(for:size:)`; files get a Quick Look thumbnail when one is ready.
@Observable
final class PopupIconCache {
    static let shared = PopupIconCache()

    @ObservationIgnored private var images: [Key: NSImage] = [:]
    @ObservationIgnored private var names: [URL: String] = [:]
    @ObservationIgnored private var thumbnailsRequested: Set<Key> = []
    @ObservationIgnored private var warmTask: Task<Void, Never>?
    @ObservationIgnored private var observer: NSObjectProtocol?
    /// Bumped when a thumbnail arrives, so views showing the plain icon refresh.
    private(set) var generation = 0

    nonisolated private struct Key: Hashable {
        var url: URL
        var size: Int
    }

    /// Sizes are rounded to steps of 8 pt so live zoom does not fill the cache with near duplicates.
    nonisolated static func bucket(_ size: CGFloat) -> Int {
        max(16, Int((size / 8).rounded(.up)) * 8)
    }

    func icon(for item: DockItem, size: CGFloat) -> NSImage {
        let key = Key(url: item.url, size: Self.bucket(size))
        if let img = images[key] { return img }
        let img = rasterize(IconRenderer.icon(for: item, size: CGFloat(key.size)), size: CGFloat(key.size))
        images[key] = img
        requestThumbnail(for: item, key: key)
        return img
    }

    /// Display name without asking the file system again. Custom names are never cached.
    func name(for item: DockItem) -> String {
        if let custom = item.customName, !custom.isEmpty { return custom }
        if let n = names[item.url] { return n }
        let n = item.displayName
        names[item.url] = n
        return n
    }

    /// True when the icon is already rendered.
    func hasIcon(for item: DockItem, size: CGFloat) -> Bool {
        images[Key(url: item.url, size: Self.bucket(size))] != nil
    }

    /// Starts watching the library and warms the cache shortly after launch.
    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: .libraryDidChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { PopupIconCache.shared.scheduleWarm(after: 0.6) }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { PopupIconCache.shared.purge() }
        }
        scheduleWarm(after: 1.0)
    }

    func purge() {
        images.removeAll()
        names.removeAll()
        thumbnailsRequested.removeAll()
        scheduleWarm(after: 0.3)
    }

    /// Renders every item icon at the size its group uses, a few per run loop turn.
    func scheduleWarm(after delay: Double) {
        warmTask?.cancel()
        warmTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            let store = LibraryStore.shared
            var work: [(DockItem, CGFloat)] = []
            for group in store.library.groups {
                let style = store.popupStyle(of: group)
                let metrics = PopupMetrics.compute(PopupLayoutInput(style: style, itemCount: group.items.count))
                for item in store.visibleItems(of: group) { work.append((item, metrics.iconSize)) }
            }
            // Drop entries of items that are gone.
            let live = Set(work.map(\.0.url))
            images = images.filter { live.contains($0.key.url) }
            names = names.filter { live.contains($0.key) }
            for (n, (item, size)) in work.enumerated() {
                if Task.isCancelled { return }
                _ = icon(for: item, size: size)
                _ = name(for: item)
                if n % 6 == 5 { await Task.yield() }
            }
        }
    }

    // MARK: Private

    private func rasterize(_ source: NSImage, size: CGFloat) -> NSImage {
        let scale = max(NSScreen.screens.map(\.backingScaleFactor).max() ?? 2, 1)
        let px = Int(size * scale)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return source }
        rep.size = NSSize(width: size, height: size)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let img = NSImage(size: NSSize(width: size, height: size))
        img.addRepresentation(rep)
        return img
    }

    /// Quick Look thumbnails for documents and images. Folders, apps and links keep their icon.
    private func requestThumbnail(for item: DockItem, key: Key) {
        guard item.kind == .file, !thumbnailsRequested.contains(key) else { return }
        thumbnailsRequested.insert(key)
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(fileAt: item.url, size: CGSize(width: key.size, height: key.size),
                                                   scale: scale, representationTypes: .thumbnail)
        request.iconMode = true
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
            guard let cg = rep?.cgImage else { return }
            let size = CGFloat(key.size)
            Task { @MainActor in
                let img = NSImage(cgImage: cg, size: NSSize(width: size, height: size))
                PopupIconCache.shared.images[key] = img
                PopupIconCache.shared.generation += 1
            }
        }
    }
}
