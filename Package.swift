// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeZoner",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TimeZoner",
            path: "Sources"
        ),
        .testTarget(
            name: "TimeZonerTests",
            dependencies: ["TimeZoner"],
            path: "Tests"
        )
    ]
)
