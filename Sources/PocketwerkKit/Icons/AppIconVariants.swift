import AppKit
import CoreImage
import SwiftUI

/// Color variants of the app's own icon. Applied at runtime to the main app's Dock tile;
/// the bundle stays untouched, so its signature stays valid.
enum AppIconVariant: String, CaseIterable, Identifiable {
    case standard, honey, ocean, graphite, iris
    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: String(localized: "Standard")
        case .honey: String(localized: "Honey")
        case .ocean: String(localized: "Ocean")
        case .graphite: String(localized: "Graphite")
        case .iris: String(localized: "Iris")
        }
    }

    /// Tint and how strongly it replaces the original colors.
    fileprivate var tint: (RGBA, Double)? {
        switch self {
        case .standard: nil
        case .honey: (RGBA(hex: "#F2A93B"), 0.8)
        case .ocean: (RGBA(hex: "#2F7BEA"), 0.8)
        case .graphite: (RGBA(hex: "#7D8590"), 0.92)
        case .iris: (RGBA(hex: "#8B5CF6"), 0.8)
        }
    }

    init(id: String) { self = AppIconVariant(rawValue: id) ?? .standard }
}

enum AppIconVariants {
    private static var cache: [AppIconVariant: NSImage] = [:]
    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// The app icon as the bundle has it.
    static var original: NSImage { NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath) }

    /// The icon in a variant, 512 px, cached.
    static func image(_ variant: AppIconVariant) -> NSImage {
        if let hit = cache[variant] { return hit }
        guard let (tint, amount) = variant.tint else { return original }
        // The Dock shows applicationIconImage flat, without glass, so scripts/make-icon.sh
        // renders the glass variants ahead of time. The tint below is the fallback.
        if let url = Bundle.main.url(forResource: "AppIcon-\(variant.rawValue)", withExtension: "heic"),
           let glass = NSImage(contentsOf: url) {
            glass.size = NSSize(width: 512, height: 512)
            cache[variant] = glass
            return glass
        }
        let base = original
        var rect = CGRect(x: 0, y: 0, width: 512, height: 512)
        guard let cg = base.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return base }
        let input = CIImage(cgImage: cg)
        // Keep the light and shade of the original, swap its colors for the tint.
        let mono = input.applyingFilter("CIColorMonochrome", parameters: [
            kCIInputColorKey: CIColor(red: tint.r, green: tint.g, blue: tint.b),
            kCIInputIntensityKey: amount,
        ]).applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.08, kCIInputSaturationKey: 1.1])
        guard let out = context.createCGImage(mono, from: input.extent) else { return base }
        let image = NSImage(cgImage: out, size: NSSize(width: 512, height: 512))
        cache[variant] = image
        return image
    }

    /// Sets the main app's Dock icon. Standard restores the bundle icon.
    static func apply(_ variant: AppIconVariant) {
        NSApp.applicationIconImage = variant == .standard ? nil : image(variant)
    }

    /// Applies the variant stored in the settings. Call once at launch.
    static func applyCurrent(_ store: LibraryStore = .shared) {
        apply(AppIconVariant(id: store.settings.appIconVariant))
    }
}

/// Picker for the app icon variant, for the settings window.
struct AppIconVariantPicker: View {
    var store: LibraryStore = .shared

    var body: some View {
        let current = AppIconVariant(id: store.settings.appIconVariant)
        HStack(spacing: 14) {
            ForEach(AppIconVariant.allCases) { variant in
                PickTile(title: variant.title, selected: variant == current, action: {
                    store.settings.appIconVariant = variant.rawValue
                    AppIconVariants.apply(variant)
                }) {
                    Image(nsImage: AppIconVariants.image(variant))
                        .resizable()
                        .frame(width: 52, height: 52)
                        .padding(4)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("App Icon"))
    }
}
