// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StatusApp",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "MetricsCore",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("SystemConfiguration"),
            ]
        ),
        .testTarget(
            name: "MetricsCoreTests",
            dependencies: ["MetricsCore"]
        ),
    ]
)
