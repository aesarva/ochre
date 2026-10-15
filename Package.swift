// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Ochre",
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
            name: "Ochre",
            dependencies: ["MetricsCore"]
        ),
        .testTarget(
            name: "MetricsCoreTests",
            dependencies: ["MetricsCore"]
        ),
    ]
)
