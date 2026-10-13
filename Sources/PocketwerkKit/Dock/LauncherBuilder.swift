import AppKit
import CryptoKit
import ImageIO
import PocketwerkShared
import UniformTypeIdentifiers

/// Everything that makes one launcher bundle different from the template.
nonisolated struct LauncherSpec: Hashable, Sendable {
    enum Kind: String, Sendable { case slot, spacer }
    var id: UUID
    var kind: Kind = .slot
    /// Name shown under the Dock tile (CFBundleName / CFBundleDisplayName).
    var name: String
    var mainAppPath = ""
    var buildID = ""
    /// Only set for development runs, so the launcher reads the same data folder as the app.
    var dataDir: String?

    var bundleID: String {
        (kind == .spacer ? PWShared.spacerBundleIDPrefix : PWShared.launcherBundleIDPrefix) + id.uuidString
    }
}

/// Where the launcher binary and base Info.plist come from.
nonisolated struct LauncherTemplate: Sendable {
    var binary: URL
    var info: [String: String]
    var infoURL: URL?
    var buildID: String

    /// The app's `LauncherTemplate.app`, $POCKETWERK_LAUNCHER_TEMPLATE, or (development) the
    /// `PocketwerkLauncher` binary next to the running executable.
    static func locate() -> LauncherTemplate? {
        var candidates: [URL] = []
        if let env = ProcessInfo.processInfo.environment["POCKETWERK_LAUNCHER_TEMPLATE"], !env.isEmpty {
            candidates.append(URL(fileURLWithPath: env))
        }
        if let res = Bundle.main.resourceURL { candidates.append(res.appendingPathComponent("LauncherTemplate.app")) }
        for app in candidates {
            let bin = app.appendingPathComponent("Contents/MacOS/PocketwerkLauncher")
            let info = app.appendingPathComponent("Contents/Info.plist")
            if FileManager.default.isExecutableFile(atPath: bin.path) {
                return LauncherTemplate(binary: bin, info: [:], infoURL: info, buildID: buildID(of: bin))
            }
        }
        let sibling = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
            .deletingLastPathComponent().appendingPathComponent("PocketwerkLauncher")
        if FileManager.default.isExecutableFile(atPath: sibling.path) {
            return LauncherTemplate(binary: sibling, info: [:], infoURL: nil, buildID: buildID(of: sibling))
        }
        return nil
    }

    /// Content hash of the binary plus the format number. A new app version gives a new id.
    static func buildID(of binary: URL) -> String {
        guard let data = try? Data(contentsOf: binary, options: .mappedIfSafe) else { return "f\(PWShared.launcherFormat)" }
        let hex = SHA256.hash(data: data).prefix(6).map { String(format: "%02x", $0) }.joined()
        return "f\(PWShared.launcherFormat)-\(hex)"
    }

    func baseInfo() -> [String: Any] {
        if let infoURL, let data = try? Data(contentsOf: infoURL),
           let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            return dict
        }
        return LauncherBuilder.defaultInfo
    }
}

nonisolated enum LauncherError: LocalizedError {
    case noTemplate, invalidBundle(String), command(String, String)

    var errorDescription: String? {
        switch self {
        case .noTemplate: String(localized: "The launcher template is missing from the app.")
        case .invalidBundle(let path): String(localized: "The new launcher is not valid: \(path)")
        case .command(let cmd, let output): String(localized: "\(cmd) failed: \(output)")
        }
    }
}

/// Builds launcher bundles. File work only; safe to run off the main thread.
nonisolated enum LauncherBuilder {
    /// Same keys as Resources/LauncherInfo.plist, used when running from a plain build folder.
    static let defaultInfo: [String: Any] = [
        "CFBundleDevelopmentRegion": "en",
        "CFBundleExecutable": "PocketwerkLauncher",
        "CFBundleIconFile": "AppIcon",
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "1.0",
        "CFBundleVersion": "1",
        "LSMinimumSystemVersion": "26.0",
        "LSUIElement": true,
        "NSHighResolutionCapable": true,
        "NSPrincipalClass": "NSApplication",
        "CFBundleDocumentTypes": [[
            "CFBundleTypeName": "Any Item",
            "CFBundleTypeRole": "Viewer",
            "LSHandlerRank": "None",
            "LSItemContentTypes": ["public.item", "public.folder"],
        ] as [String: Any]],
    ]

    /// File name for a bundle: no "/" or ":", no leading dot, at most 60 characters.
    static func bundleName(for name: String) -> String {
        var s = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        s = s.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        while s.hasPrefix(".") { s.removeFirst() }
        if s.count > 60 { s = String(s.prefix(60)).trimmingCharacters(in: .whitespaces) }
        return s.isEmpty ? "Pocketwerk" : s
    }

    /// The template Info.plist with the launcher's identity filled in.
    static func patchedInfo(base: [String: Any], spec: LauncherSpec) -> [String: Any] {
        var info = base
        let shown = spec.name.isEmpty ? " " : spec.name
        info["CFBundleIdentifier"] = spec.bundleID
        info["CFBundleName"] = shown
        info["CFBundleDisplayName"] = shown
        info["CFBundleExecutable"] = "PocketwerkLauncher"
        info["CFBundleIconFile"] = "AppIcon"
        info["LSUIElement"] = true
        info[PWShared.slotInfoKey] = spec.id.uuidString
        info[PWShared.kindInfoKey] = spec.kind.rawValue
        info[PWShared.mainAppPathInfoKey] = spec.mainAppPath
        info[PWShared.buildIDInfoKey] = spec.buildID
        if let dir = spec.dataDir { info[PWShared.dataDirInfoKey] = dir } else { info.removeValue(forKey: PWShared.dataDirInfoKey) }
        if spec.kind == .spacer { info.removeValue(forKey: "CFBundleDocumentTypes") }
        return info
    }

    static func readInfo(_ bundle: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: bundle.appendingPathComponent("Contents/Info.plist")) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    /// True when the bundle at `url` was built for `spec` from the current template.
    static func isCurrent(_ url: URL, spec: LauncherSpec) -> Bool {
        guard let info = readInfo(url) else { return false }
        return info[PWShared.buildIDInfoKey] as? String == spec.buildID
            && info["CFBundleName"] as? String == (spec.name.isEmpty ? " " : spec.name)
            && info["CFBundleIdentifier"] as? String == spec.bundleID
            && info[PWShared.mainAppPathInfoKey] as? String == spec.mainAppPath
            && info[PWShared.dataDirInfoKey] as? String == spec.dataDir
    }

    /// Builds a fresh bundle next to `destination`, signs it, then swaps its Contents into
    /// `destination`. The bundle folder itself stays, so a Dock pin keeps pointing at it, and the
    /// old Contents are kept until the new ones are valid.
    static func build(spec: LauncherSpec, template: LauncherTemplate, iconPNG: Data?, destination: URL) throws {
        let fm = FileManager.default
        let parent = destination.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent(".staging-\(spec.id.uuidString).app", isDirectory: true)
        try? fm.removeItem(at: staging)
        defer { try? fm.removeItem(at: staging) }

        let contents = staging.appendingPathComponent("Contents", isDirectory: true)
        try fm.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        try fm.createDirectory(at: contents.appendingPathComponent("Resources"), withIntermediateDirectories: true)
        try fm.copyItem(at: template.binary, to: contents.appendingPathComponent("MacOS/PocketwerkLauncher"))
        let info = patchedInfo(base: template.baseInfo(), spec: spec)
        let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try plist.write(to: contents.appendingPathComponent("Info.plist"))
        if let iconPNG { try writeICNS(png: iconPNG, to: contents.appendingPathComponent("Resources/AppIcon.icns")) }
        // Always sign the copy: the patched Info.plist breaks any template signature.
        try run("/usr/bin/codesign", ["--force", "--sign", "-", "--timestamp=none", staging.path])
        guard readInfo(staging)?["CFBundleIdentifier"] as? String == spec.bundleID else {
            throw LauncherError.invalidBundle(staging.path)
        }

        if fm.fileExists(atPath: destination.path) {
            clearCustomIcon(destination)
            let old = destination.appendingPathComponent("Contents.old", isDirectory: true)
            try? fm.removeItem(at: old)
            let current = destination.appendingPathComponent("Contents", isDirectory: true)
            if fm.fileExists(atPath: current.path) { try fm.moveItem(at: current, to: old) }
            do {
                try fm.moveItem(at: contents, to: current)
            } catch {
                try? fm.moveItem(at: old, to: current)
                throw error
            }
            try? fm.removeItem(at: old)
        } else {
            try fm.moveItem(at: staging, to: destination)
        }
    }

    /// Writes a multi-size .icns from a 1024 PNG with ImageIO.
    static func writeICNS(png: Data, to url: URL) throws {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.icns.identifier as CFString, 5, nil)
        else { throw LauncherError.invalidBundle(url.path) }
        for size in [16, 32, 128, 256, 512] {
            if let scaled = scale(image, to: size) { CGImageDestinationAddImage(dest, scaled, nil) }
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw LauncherError.invalidBundle(url.path) }
    }

    private static func scale(_ image: CGImage, to size: Int) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        return ctx.makeImage()
    }

    /// Removes a Finder custom icon (the `Icon\r` file and its FinderInfo flag).
    static func clearCustomIcon(_ bundle: URL) {
        try? FileManager.default.removeItem(at: bundle.appendingPathComponent("Icon\r"))
        removexattr(bundle.path, "com.apple.FinderInfo", 0)
    }

    static func register(_ bundle: URL) {
        _ = try? run(lsregister, ["-f", bundle.path])
    }

    static func unregister(_ bundle: URL) {
        _ = try? run(lsregister, ["-u", bundle.path])
    }

    static let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    @discardableResult
    static func run(_ tool: String, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let out = String(decoding: data, as: UTF8.self)
        guard p.terminationStatus == 0 else {
            throw LauncherError.command(([tool] + args).joined(separator: " "), out)
        }
        return out
    }
}
