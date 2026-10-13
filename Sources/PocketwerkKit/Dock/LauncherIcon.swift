import AppKit
import CryptoKit

/// Turns icon art into launcher icons that sit right next to the system's own Dock icons.
enum LauncherIcon {
    /// Art edge relative to the 1024 canvas. Matches the size macOS 26 draws neighbouring app icons at.
    static let artScale: CGFloat = 0.832
    /// Art edge used for the Finder custom icon (the at-rest Dock tile).
    static let customIconScale: CGFloat = 0.86
    /// Corner radius relative to the art edge.
    static let cornerRatio: CGFloat = 0.2237

    /// Draws `art` (full-bleed, square) centered on a transparent canvas, clipped to the rounded rect
    /// unless `clip` is false (circles, plain text, images with their own shape).
    static func compose(_ art: NSImage, canvas: CGFloat = 1024, scale: CGFloat = artScale, clip: Bool = true) -> NSImage {
        NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { _ in
            let edge = canvas * scale
            let rect = NSRect(x: (canvas - edge) / 2, y: (canvas - edge) / 2, width: edge, height: edge)
            if clip {
                NSBezierPath(roundedRect: rect, xRadius: edge * cornerRatio, yRadius: edge * cornerRatio).addClip()
            }
            art.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
    }

    /// PNG of an image at an exact pixel size.
    static func png(_ image: NSImage, pixels: Int) -> Data? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    /// Short hash of any encodable icon inputs. A change means the icon must be drawn again.
    nonisolated static func hash<T: Encodable>(_ value: T) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = .sortedKeys
        let data = (try? enc.encode(value)) ?? Data()
        return SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Inputs

    /// Everything a slot icon depends on.
    nonisolated struct SlotInputs: Encodable {
        var name: String
        var icon: IconSpec?
        var groups: [GroupInputs]
    }

    nonisolated struct GroupInputs: Encodable {
        var name: String
        var icon: IconSpec
        var background: Background
        var items: [URL]
    }

    static func inputs(for slot: DockSlot, library: Library) -> SlotInputs {
        SlotInputs(name: slot.name, icon: slot.icon, groups: slot.groupIDs.compactMap { library.group($0) }.map {
            GroupInputs(name: $0.name, icon: $0.icon, background: $0.style.background, items: Array($0.sortedItems.prefix(16).map(\.url)))
        })
    }

    static func shape(for slot: DockSlot, library: Library) -> IconShape {
        (slot.icon ?? slot.groupIDs.compactMap { library.group($0) }.first?.icon)?.shape ?? .squircle
    }

    // MARK: Spacers

    /// Spacer tile art: the image, or the text fitted into the tile, on the spacer's background (if any).
    static func spacerArt(_ spacer: CustomSpacer, size: CGFloat = 1024) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            if let bg = spacer.icon.background {
                switch bg {
                case .solid(let c): c.nsColor.setFill(); rect.fill()
                case .gradient(let colors, _), .mesh(let colors):
                    NSGradient(colors: colors.map(\.nsColor))?.draw(in: rect, angle: -90)
                default: break
                }
            }
            if let path = spacer.imagePath, let image = NSImage(contentsOfFile: path) {
                let s = image.size
                let k = min(rect.width / max(s.width, 1), rect.height / max(s.height, 1))
                let w = s.width * k, h = s.height * k
                image.draw(in: NSRect(x: (rect.width - w) / 2, y: (rect.height - h) / 2, width: w, height: h))
                return true
            }
            let text = spacer.text.isEmpty ? "·" : spacer.text
            var fontSize = size * 0.42
            let color = spacer.icon.foreground.nsColor
            func attrs(_ fs: CGFloat) -> [NSAttributedString.Key: Any] {
                let base = NSFont.systemFont(ofSize: fs, weight: .bold)
                let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: fs) } ?? base
                return [.font: font, .foregroundColor: color]
            }
            var str = NSAttributedString(string: text, attributes: attrs(fontSize))
            while str.size().width > size * 0.92, fontSize > 40 {
                fontSize *= 0.9
                str = NSAttributedString(string: text, attributes: attrs(fontSize))
            }
            let sz = str.size()
            str.draw(at: NSPoint(x: (size - sz.width) / 2, y: (size - sz.height) / 2))
            return true
        }
    }
}
