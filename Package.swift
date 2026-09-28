// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PortPilot",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PortPilotCore"),
        .executableTarget(
            name: "PortPilot",
            dependencies: ["PortPilotCore"]
        ),
        .testTarget(
            name: "PortPilotTests",
            dependencies: ["PortPilotCore"]
        )
    ]
)
