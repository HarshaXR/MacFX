// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MacFX",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "MacFX", path: "Sources/MacFX")
    ]
)
