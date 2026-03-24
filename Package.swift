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
            path: "Tests",
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-external-plugin-path",
                    "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing#/Library/Developer/CommandLineTools/usr/bin/swift-plugin-server"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-framework", "Testing",
                    "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ]
        )
    ]
)
