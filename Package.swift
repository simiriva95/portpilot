// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PortPilot",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PortPilot",
            path: "Sources/PortPilot"
        )
    ]
)
