// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "consuming-semantics",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "consuming-semantics"
        )
    ]
)
