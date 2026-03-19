// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ZeldaSwift",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ZeldaCore", targets: ["ZeldaCore"]),
        .library(name: "ZeldaContent", targets: ["ZeldaContent"]),
        .library(name: "ZeldaUI", targets: ["ZeldaUI"]),
        .library(name: "ZeldaTelemetry", targets: ["ZeldaTelemetry"]),
        .library(name: "ZeldaExtractCLI", targets: ["ZeldaExtractCLI"]),
        .library(name: "ZeldaHarness", targets: ["ZeldaHarness"]),
        .executable(name: "zelda-mac", targets: ["ZeldaMac"]),
        .executable(name: "zelda-extract", targets: ["ZeldaExtractMain"])
    ],
    targets: [
        .target(
            name: "ZeldaCore",
            path: "Sources/ZeldaCore"
        ),
        .target(
            name: "ZeldaContent",
            path: "Sources/ZeldaContent"
        ),
        .target(
            name: "ZeldaTelemetry",
            path: "Sources/ZeldaTelemetry"
        ),
        .target(
            name: "ZeldaUI",
            dependencies: ["ZeldaCore", "ZeldaContent"],
            path: "Sources/ZeldaUI"
        ),
        .target(
            name: "ZeldaExtractCLI",
            dependencies: ["ZeldaContent"],
            path: "Sources/ZeldaExtractCLI"
        ),
        .target(
            name: "ZeldaHarness",
            dependencies: ["ZeldaCore", "ZeldaContent", "ZeldaTelemetry"],
            path: "Sources/ZeldaHarness"
        ),
        .executableTarget(
            name: "ZeldaMac",
            dependencies: ["ZeldaCore", "ZeldaContent", "ZeldaUI"],
            path: "App/ZeldaMac/Sources"
        ),
        .executableTarget(
            name: "ZeldaExtractMain",
            dependencies: ["ZeldaExtractCLI"],
            path: "Sources/ZeldaExtractMain"
        ),
        .testTarget(
            name: "ZeldaCoreTests",
            dependencies: ["ZeldaCore"],
            path: "Tests/ZeldaCoreTests"
        ),
        .testTarget(
            name: "ZeldaContentTests",
            dependencies: ["ZeldaContent"],
            path: "Tests/ZeldaContentTests"
        ),
        .testTarget(
            name: "ZeldaExtractTests",
            dependencies: ["ZeldaExtractCLI"],
            path: "Tests/ZeldaExtractTests"
        ),
        .testTarget(
            name: "ZeldaUITests",
            dependencies: ["ZeldaUI", "ZeldaCore", "ZeldaContent"],
            path: "Tests/ZeldaUITests"
        )
    ]
)
