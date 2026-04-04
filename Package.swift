// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KalshiQuickSearch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "KalshiQuickSearchApp",
            targets: ["KalshiQuickSearchApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "KalshiQuickSearchApp"
        ),
        .testTarget(
            name: "KalshiQuickSearchTests",
            dependencies: ["KalshiQuickSearchApp"]
        )
    ]
)
