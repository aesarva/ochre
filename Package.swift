// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StatusApp",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "CPrivateAPI",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
        .target(
            name: "MetricsCore",
            dependencies: ["CPrivateAPI"],
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
