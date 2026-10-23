// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Ochre",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
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
            dependencies: ["MetricsCore", .product(name: "Sparkle", package: "Sparkle")],
            // Sparkle.framework кладётся в Contents/Frameworks (scripts/build-app.sh).
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(
            name: "MetricsCoreTests",
            dependencies: ["MetricsCore"]
        ),
    ]
)
