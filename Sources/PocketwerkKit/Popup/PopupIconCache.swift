import AppKit
import Observation
import QuickLookThumbnailing

/// Uses the shared item bitmaps and loads file previews on demand.
/// Wraps `IconRenderer.icon(for:size:)`; files get a Quick Look thumbnail when one is ready.
@Observable
final class PopupIconCache {
    static let shared = PopupIconCache()

    private final class FilePreview {
        var thumbnail: NSImage?
    }

    @ObservationIgnored private let previews = NSCache<NSString, FilePreview>()
    @ObservationIgnored private var names: [URL: String] = [:]
    @ObservationIgnored private var observer: NSObjectProtocol?
    private(set) var generation = 0

    init() {
        previews.countLimit = 128
        previews.totalCostLimit = 8 * 1024 * 1024
    }

    /// Sizes are rounded to steps of 8 pt so live zoom does not fill the cache with near duplicates.
    nonisolated static func bucket(_ size: CGFloat) -> Int {
        max(16, Int((size / 8).rounded(.up)) * 8)
    }

    func icon(for item: DockItem, size: CGFloat) -> NSImage {
        let points = CGFloat(Self.bucket(size))
        if item.kind == .file {
            let key = "\(Int(points))|\(item.url.absoluteString)" as NSString
            if let preview = previews.object(forKey: key) {
                if let image = preview.thumbnail { return image }
            } else {
                let preview = FilePreview()
                let scale = NSScreen.main?.backingScaleFactor ?? 2
                let pixels = Int((points * scale).rounded(.up))
                previews.setObject(preview, forKey: key, cost: pixels * pixels * 4)
                requestThumbnail(for: item.url, size: points, scale: scale, preview: preview)
            }
        }
        return IconRenderer.icon(for: item, size: points)
    }

    /// Display name without asking the file system again. Custom names are never cached.
    func name(for item: DockItem) -> String {
        if let custom = item.customName, !custom.isEmpty { return custom }
        if let n = names[item.url] { return n }
        let n = item.displayName
        names[item.url] = n
        return n
    }

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: .libraryDidChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { PopupIconCache.shared.purge() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { PopupIconCache.shared.purge() }
        }
        // A favicon arrived: drop cached link icons so the new one shows.
        NotificationCenter.default.addObserver(forName: .itemIconsDidChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { PopupIconCache.shared.purge() }
        }
    }

    func purge() {
        previews.removeAllObjects()
        names.removeAll()
        generation += 1
    }

    private func requestThumbnail(for url: URL, size: CGFloat, scale: CGFloat, preview: FilePreview) {
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: size, height: size),
                                                   scale: scale, representationTypes: .thumbnail)
        request.iconMode = true
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak preview] rep, _ in
            guard let cg = rep?.cgImage else { return }
            Task { @MainActor [weak preview] in
                guard let preview else { return }
                preview.thumbnail = NSImage(cgImage: cg, size: NSSize(width: size, height: size))
                PopupIconCache.shared.generation += 1
            }
        }
    }
}
