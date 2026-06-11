// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Quackpilot",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Quackpilot",
            path: "Sources/Quackpilot",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "QuackpilotTests",
            dependencies: ["Quackpilot"],
            path: "Tests/QuackpilotTests"
        )
    ]
)
