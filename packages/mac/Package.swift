// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TruthPulse",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TruthPulseCore",
            targets: ["TruthPulseCore"]
        ),
        .executable(
            name: "TruthPulse",
            targets: ["TruthPulse"]
        )
    ],
    targets: [
        .target(
            name: "TruthPulseCore"
        ),
        .executableTarget(
            name: "TruthPulse",
            dependencies: ["TruthPulseCore"]
        ),
        .target(
            name: "TruthPulseIOS",
            dependencies: ["TruthPulseCore"]
        ),
        .testTarget(
            name: "TruthPulseTests",
            dependencies: ["TruthPulseCore"]
        )
    ]
)
