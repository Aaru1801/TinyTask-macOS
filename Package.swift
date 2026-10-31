// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TinyRecorder",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TinyRecorder", targets: ["TinyRecorder"])
    ],
    targets: [
        .executableTarget(
            name: "TinyRecorder",
            path: "Sources/TinyRecorder",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "TinyRecorderTests",
            dependencies: ["TinyRecorder"]
        )
    ]
)
