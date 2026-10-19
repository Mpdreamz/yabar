// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "Yabar",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "YabarApp", targets: ["YabarApp"]),
        .executable(name: "yabar", targets: ["yabar"]),
    ],
    // The updater (MIT): checks yabar's appcast, verifies each download's EdDSA signature, installs and relaunches.
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .target(name: "YabarCore"),
        .executableTarget(
            name: "YabarApp",
            dependencies: ["YabarCore", .product(name: "Sparkle", package: "Sparkle")]
        ),
        // The command line tool, for skhd: Contents/Helpers/yabar, linked onto the PATH by the cask.
        .executableTarget(name: "yabar", dependencies: ["YabarCore"]),
        .testTarget(name: "YabarCoreTests", dependencies: ["YabarCore"]),
    ]
)
