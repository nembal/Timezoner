// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeZoner",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "TimeZonerLib",
            path: "Sources",
            exclude: ["App"],
            sources: ["Data", "Models", "Stores", "Parser", "Utilities", "Views"]
        ),
        .executableTarget(
            name: "TimeZoner",
            dependencies: ["TimeZonerLib"],
            path: "Sources/App"
        ),
        .executableTarget(
            name: "TimeZonerTests",
            dependencies: ["TimeZonerLib"],
            path: "Tests"
        )
    ]
)
