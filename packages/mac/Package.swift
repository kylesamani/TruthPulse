// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TruthPulse",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "TruthPulse",
            targets: ["TruthPulse"]
        )
    ],
    targets: [
        .executableTarget(
            name: "TruthPulse"
        ),
        .testTarget(
            name: "TruthPulseTests",
            dependencies: ["TruthPulse"]
        )
    ]
)
