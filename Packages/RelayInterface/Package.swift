// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "RelayInterface",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "RelayInterface", targets: ["RelayInterface"]),
    ],
    targets: [
        .target(
            name: "RelayInterface",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
