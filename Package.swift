// swift-tools-version: 6.2
import PackageDescription

let mainActorByDefault: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .swiftLanguageMode(.v5),
]

let package = Package(
    name: "Pocketwerk",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "Pocketwerk", targets: ["Pocketwerk"]),
        .executable(name: "PocketwerkLauncher", targets: ["PocketwerkLauncher"]),
    ],
    targets: [
        // Constants shared by the main app and the per-slot launcher.
        .target(name: "PocketwerkShared", swiftSettings: [.swiftLanguageMode(.v5)]),
        // Everything the main app does. Kept as a library so tests can import it.
        .target(
            name: "PocketwerkKit",
            dependencies: ["PocketwerkShared"],
            swiftSettings: mainActorByDefault,
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("QuickLookUI"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .executableTarget(name: "Pocketwerk", dependencies: ["PocketwerkKit"], swiftSettings: mainActorByDefault),
        // Tiny app copied into every generated Dock launcher bundle.
        .executableTarget(name: "PocketwerkLauncher", dependencies: ["PocketwerkShared"], swiftSettings: mainActorByDefault),
        .testTarget(name: "PocketwerkKitTests", dependencies: ["PocketwerkKit"], swiftSettings: mainActorByDefault),
    ]
)
