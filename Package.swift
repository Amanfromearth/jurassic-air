// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "JurassicAir",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "JurassicAir",
            path: "Sources/JurassicAir",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "JurassicAirTests",
            dependencies: ["JurassicAir"],
            path: "Tests/JurassicAirTests"
        )
    ]
)
