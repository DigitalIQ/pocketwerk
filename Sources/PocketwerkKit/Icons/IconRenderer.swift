import AppKit

/// Dock icons, group icons and item icons.
///
/// Launcher icons follow the macOS grid: a 1024 px canvas, artwork at 0.832 of the edge,
/// rounded rect radius 0.2237 x artwork edge. Composed icons are cached by their inputs.
enum IconRenderer {
    /// Share of the canvas the artwork (plate) covers.
    static let artScale: CGFloat = 0.832
    /// Corner radius of the squircle relative to the artwork edge.
    static let cornerRatio: CGFloat = 0.2237

    // MARK: Items

    /// Icon of a single item (app icon, file icon, folder icon, favicon or globe for links).
    static func icon(for item: DockItem, size: CGFloat) -> NSImage {
        ItemIconCache.shared.icon(for: item, size: size)
    }

    // MARK: Groups and slots

    /// Dock icon / folder icon for a group, drawn from its IconSpec and style, in visible sort order.
    static func groupIcon(_ group: ItemGroup, size: CGFloat) -> NSImage {
        render(spec: effectiveSpec(group), style: group.style, name: group.name, items: group.sortedItems, size: size)
    }

    /// Dock icon for a slot: slot.icon if set, else the first group's icon.
    static func slotIcon(_ slot: DockSlot, library: Library, size: CGFloat) -> NSImage {
        let groups = slot.groupIDs.compactMap { library.group($0) }
        let first = groups.first ?? ItemGroup(name: slot.name)
        let spec = slot.icon ?? effectiveSpec(first)
        return render(spec: spec, style: first.style, name: slot.name, items: first.sortedItems, size: size)
    }

    /// PNG of a group's Dock icon, for example 256 (runtime push) or 1024 (bundle icon).
    static func pngData(for group: ItemGroup, size: Int) -> Data? {
        png(cgImage(spec: effectiveSpec(group), style: group.style, name: group.name, items: group.sortedItems, pixels: size))
    }

    static func pngData(for slot: DockSlot, library: Library, size: Int) -> Data? {
        let groups = slot.groupIDs.compactMap { library.group($0) }
        let first = groups.first ?? ItemGroup(name: slot.name)
        let spec = slot.icon ?? effectiveSpec(first)
        return png(cgImage(spec: spec, style: first.style, name: slot.name, items: first.sortedItems, pixels: size))
    }

    /// Smart groups have no stored items, so their grid would be empty: show a symbol instead.
    private static func effectiveSpec(_ group: ItemGroup) -> IconSpec {
        guard let smart = group.smart, group.items.isEmpty else { return group.icon }
        var spec = group.icon
        switch spec.content {
        case .itemGrid, .itemStack:
            let symbol = switch smart {
            case .mostUsed: "star.fill"
            case .recentlyOpened: "clock.fill"
            case .runningApps: "bolt.fill"
            }
            spec.content = .symbol(name: symbol)
        default: break
        }
        return spec
    }

    // MARK: Rendering

    /// Point-sized image. Small sizes render at 2x for Retina.
    static func render(spec: IconSpec, style: GroupStyle, name: String, items: [DockItem], size: CGFloat) -> NSImage {
        let scale: CGFloat = size >= 256 ? 1 : 2
        guard let cg = cgImage(spec: spec, style: style, name: name, items: items, pixels: Int((size * scale).rounded())) else {
            return NSImage(size: NSSize(width: size, height: size))
        }
        return NSImage(cgImage: cg, size: NSSize(width: size, height: size))
    }

    private static var cache: [Int: CGImage] = [:]
    private static var cacheOrder: [Int] = []

    /// Square bitmap of `pixels` edge length. Cached by every input that changes the picture.
    static func cgImage(spec: IconSpec, style: GroupStyle, name: String, items: [DockItem], pixels: Int) -> CGImage? {
        guard pixels > 0 else { return nil }
        var h = Hasher()
        h.combine(spec)
        h.combine(style.background)
        h.combine(name)
        h.combine(items.map(\.url))
        h.combine(pixels)
        h.combine(ItemIconCache.shared.generation)
        let key = h.finalize()
        if let hit = cache[key] { return hit }
        guard let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ns
        IconPainter(ctx: ctx, canvas: CGFloat(pixels), spec: spec, style: style, name: name, items: items).paint()
        NSGraphicsContext.restoreGraphicsState()
        guard let image = ctx.makeImage() else { return nil }
        cache[key] = image
        cacheOrder.append(key)
        if cacheOrder.count > 160 { cache.removeValue(forKey: cacheOrder.removeFirst()) }
        return image
    }

    static func png(_ image: CGImage?) -> Data? {
        guard let image else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}
