// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-testing-crash",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .testTarget(
            name: "CrashTests",
            dependencies: [
                .product(name: "Set Primitives", package: "swift-set-primitives"),
            ]
        )
    ]
)
