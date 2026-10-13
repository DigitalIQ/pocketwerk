import AppKit
import CoreImage
import SwiftUI

/// A CGImage that may cross into a background task. CGImage is immutable.
struct ImageBox: @unchecked Sendable {
    let image: CGImage
}

/// Image decoding and blurring, off the main thread.
nonisolated enum ImageProcessing {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// Loads an image file downsampled to `maxPixel` on its long edge and blurs it by `sigma` pixels.
    static func load(url: URL, maxPixel: Int, sigma: Double) -> ImageBox? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        guard sigma > 0.3 else { return ImageBox(image: thumb) }
        let ci = CIImage(cgImage: thumb)
        let blurred = ci.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: ci.extent)
        return context.createCGImage(blurred, from: ci.extent).map(ImageBox.init)
    }

    /// The wallpaper scaled to fill a screen of `pixelSize` (aspect fill, centered crop), then blurred.
    static func wallpaper(url: URL, pixelSize: CGSize, sigma: Double) -> ImageBox? {
        let maxPixel = Int(max(pixelSize.width, pixelSize.height) * 1.5)
        guard let box = load(url: url, maxPixel: maxPixel, sigma: 0) else { return nil }
        let src = CIImage(cgImage: box.image)
        let s = max(pixelSize.width / src.extent.width, pixelSize.height / src.extent.height)
        let scaled = src.transformed(by: CGAffineTransform(scaleX: s, y: s))
        let crop = CGRect(x: scaled.extent.midX - pixelSize.width / 2, y: scaled.extent.midY - pixelSize.height / 2,
                          width: pixelSize.width, height: pixelSize.height).integral
        var img = scaled.cropped(to: crop)
        if sigma > 0.3 {
            img = img.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: crop)
        }
        return context.createCGImage(img, from: crop).map(ImageBox.init)
    }
}

/// Cache of decoded and blurred backdrops (photos and wallpapers). Work runs in the background;
/// views show a fallback until the image is ready.
final class BackdropCache {
    static let shared = BackdropCache()

    private var images: [String: CGImage] = [:]
    private var order: [String] = []
    private var tasks: [String: Task<ImageBox?, Never>] = [:]

    func cached(_ key: String) -> CGImage? { images[key] }

    private func store(_ image: CGImage, for key: String) {
        images[key] = image
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > 12 { images.removeValue(forKey: order.removeFirst()) }
    }

    private func load(_ key: String, _ work: @escaping @Sendable () -> ImageBox?) async -> CGImage? {
        if let hit = images[key] { return hit }
        let task = tasks[key] ?? Task.detached(priority: .userInitiated) { work() }
        tasks[key] = task
        let box = await task.value
        tasks[key] = nil
        if let box { store(box.image, for: key) }
        return box?.image
    }

    // MARK: Photos

    static func photoKey(path: String, blur: Double) -> String {
        let mtime = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "photo|\(path)|\(Int(mtime))|\(Int(blur))"
    }

    func photo(path: String, blur: Double) async -> CGImage? {
        let url = URL(fileURLWithPath: path)
        // Photos are shown at popup size; 1600 px is plenty. Blur is in points of an ~800 pt wide view.
        return await load(Self.photoKey(path: path, blur: blur)) {
            ImageProcessing.load(url: url, maxPixel: 1600, sigma: blur * 2)
        }
    }

    // MARK: Wallpaper

    struct WallpaperRequest {
        var key: String
        var url: URL
        var pixelSize: CGSize
        var pointSize: CGSize
    }

    /// The desktop picture of a screen. Reading the file needs no Screen Recording permission.
    static func wallpaperRequest(for screen: NSScreen?, blur: Double) -> WallpaperRequest? {
        guard let screen = screen ?? NSScreen.main, let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
        let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)?.timeIntervalSince1970 ?? 0
        let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue ?? 0
        // Blurred wallpapers are rendered at 1x: blur hides the difference and it saves memory.
        let scale = blur > 2 ? 1 : screen.backingScaleFactor
        let px = CGSize(width: (screen.frame.width * scale).rounded(), height: (screen.frame.height * scale).rounded())
        return WallpaperRequest(key: "wall|\(id)|\(url.path)|\(Int(mtime))|\(Int(blur))", url: url, pixelSize: px, pointSize: screen.frame.size)
    }

    func wallpaper(_ request: WallpaperRequest, blur: Double) async -> CGImage? {
        let url = request.url, px = request.pixelSize
        let sigma = blur * px.width / max(1, request.pointSize.width)
        return await load(request.key) { ImageProcessing.wallpaper(url: url, pixelSize: px, sigma: sigma) }
    }
}

// MARK: - Views

/// A user photo, aspect filled, blurred and dimmed.
struct PhotoFill: View {
    var path: String
    var dim: Double
    var blur: Double
    @State private var image: CGImage?

    var body: some View {
        let key = BackdropCache.photoKey(path: path, blur: blur)
        let shown = image ?? BackdropCache.shared.cached(key)
        ZStack {
            Color(white: 0.28)
            if let shown {
                Image(decorative: shown, scale: 1).resizable().scaledToFill()
            }
            Color.black.opacity(min(0.9, max(0, dim)))
        }
        .clipped()
        .task(id: key) { image = await BackdropCache.shared.photo(path: path, blur: blur) }
    }
}

/// The blurred desktop picture. `aligned` lines it up with the desktop behind the view, so the
/// popup looks cut out of the wallpaper. Otherwise it fills the frame (previews).
struct WallpaperFill: View {
    var blur: Double
    var dim: Double
    var aligned = true

    @State private var placement = ScreenPlacement()
    @State private var image: CGImage?
    @State private var epoch = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color(white: 0.2)
                if let image {
                    if aligned, let screen = placement.screenFrame, let view = placement.viewFrame {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .frame(width: screen.width, height: screen.height)
                            .offset(x: -(view.minX - screen.minX), y: -(screen.maxY - view.maxY))
                    } else {
                        Image(decorative: image, scale: 1).resizable().scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                Color.black.opacity(min(0.9, max(0, dim)))
            }
        }
        .clipped()
        .background(WindowFrameReader { placement = $0 }.opacity(0))
        .task(id: "\(placement.screenID)|\(Int(blur))|\(epoch)") {
            guard let request = BackdropCache.wallpaperRequest(for: placement.screen, blur: blur) else { return }
            if let hit = BackdropCache.shared.cached(request.key) { image = hit; return }
            image = await BackdropCache.shared.wallpaper(request, blur: blur)
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)) { _ in epoch += 1 }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in epoch += 1 }
    }
}

/// Where a view sits on screen, in AppKit screen coordinates.
struct ScreenPlacement: Equatable {
    var screenID = 0
    var screenFrame: CGRect?
    var viewFrame: CGRect?
    weak var screen: NSScreen?

    static func == (a: ScreenPlacement, b: ScreenPlacement) -> Bool {
        a.screenID == b.screenID && a.screenFrame == b.screenFrame && a.viewFrame == b.viewFrame
    }
}

/// Reports the hosting window's screen and the view's frame on it whenever they change.
struct WindowFrameReader: NSViewRepresentable {
    var onChange: (ScreenPlacement) -> Void

    func makeNSView(context: Context) -> FrameReportingView {
        let v = FrameReportingView()
        v.onChange = onChange
        return v
    }

    func updateNSView(_ nsView: FrameReportingView, context: Context) { nsView.onChange = onChange }
}

final class FrameReportingView: NSView {
    var onChange: ((ScreenPlacement) -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var last = ScreenPlacement()

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        guard let window else { return }
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification, NSWindow.didChangeScreenNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.report() }
            })
        }
        report()
    }

    override func layout() {
        super.layout()
        report()
    }

    private func report() {
        guard let window else { return }
        var p = ScreenPlacement()
        p.screen = window.screen
        p.screenFrame = window.screen?.frame
        p.screenID = (window.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue ?? 0
        p.viewFrame = window.convertToScreen(convert(bounds, to: nil))
        guard p != last else { return }
        last = p
        DispatchQueue.main.async { [onChange] in onChange?(p) }
    }
}
