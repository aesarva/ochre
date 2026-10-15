// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StatusApp",
    platforms: [.macOS(.v26)],
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
        .executableTarget(
            name: "StatusApp",
            dependencies: ["MetricsCore"]
        ),
        .testTarget(
            name: "MetricsCoreTests",
            dependencies: ["MetricsCore"]
        ),
    ]
)
