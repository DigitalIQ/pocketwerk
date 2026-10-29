// Adapted from BAMA by Dave Ebbelaar (MIT): https://github.com/daveebbelaar/bama
import AppKit

// Puts icon renders side by side on a gray sheet, at their own pixel size.
// "--" starts a new row. Called by scripts/icon-review.sh:
//   swift icon-sheet.swift <out.png> <in.png>... [-- <in.png>...]

let args = CommandLine.arguments
let rows: [[NSBitmapImageRep]] = args.dropFirst(2)
    .split(separator: "--")
    .map { paths in
        paths.compactMap { path in
            (try? Data(contentsOf: URL(fileURLWithPath: path))).flatMap(NSBitmapImageRep.init(data:))
        }
    }
let gap = 48
let rowHeights = rows.map { ($0.map(\.pixelsHigh).max() ?? 0) + gap }
let height = rowHeights.reduce(gap, +)
let width = rows.map { $0.reduce(gap) { $0 + $1.pixelsWide + gap } }.max() ?? gap
let sheet = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: sheet)
NSColor(white: 0.55, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
var top = height - gap
for (row, rowHeight) in zip(rows, rowHeights) {
    let inner = rowHeight - gap
    var x = gap
    for rep in row {
        // ictool writes 16-bit PNGs; drawing through NSImage keeps their transparent corners.
        let image = NSImage(size: NSSize(width: rep.pixelsWide, height: rep.pixelsHigh))
        image.addRepresentation(rep)
        let y = top - inner + (inner - rep.pixelsHigh) / 2
        image.draw(in: NSRect(x: x, y: y, width: rep.pixelsWide, height: rep.pixelsHigh),
                   from: .zero, operation: .sourceOver, fraction: 1)
        x += rep.pixelsWide + gap
    }
    top -= rowHeight
}
NSGraphicsContext.current = nil
try sheet.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[1]))
