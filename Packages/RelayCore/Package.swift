// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RelayCore",
    platforms: [.macOS(.v15)],
    products: [.library(name: "RelayCore", targets: ["RelayCore"])],
    targets: [
        .target(
            name: "RelayCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
