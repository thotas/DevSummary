// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DevSummary",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "DevSummary",
            path: "Sources/DevSummary"
        )
    ]
)
