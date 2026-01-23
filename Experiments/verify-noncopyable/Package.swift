// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "verify-noncopyable",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
        .package(path: "../../../swift-hash-primitives"),
        .package(path: "../../../swift-equation-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "verify-noncopyable",
            dependencies: [
                .product(name: "Set Primitives", package: "swift-set-primitives"),
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
                .product(name: "Equation Primitives", package: "swift-equation-primitives"),
            ]
        )
    ]
)
