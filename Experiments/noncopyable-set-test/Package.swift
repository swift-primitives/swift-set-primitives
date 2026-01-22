// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "noncopyable-set-test",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-hash-primitives"),
        .package(path: "../../../swift-sequence-primitives"),
        .package(path: "../../../swift-collection-primitives"),
        .package(path: "../../../swift-property-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "noncopyable-set-test",
            dependencies: [
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        )
    ]
)
