// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-set-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "Set Primitives",
            targets: ["Set Primitives"]
        )
    ],
    dependencies: [
        .package(path: "../swift-standard-library-extensions"),
        .package(path: "../swift-bit-primitives"),
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-hash-primitives"),
        .package(path: "../swift-hash-table-primitives"),
        .package(path: "../swift-buffer-primitives"),
        .package(path: "../swift-storage-primitives"),
        .package(path: "../swift-collection-primitives"),
        .package(path: "../swift-sequence-primitives"),
        .package(path: "../swift-property-primitives"),
        .package(path: "../swift-memory-primitives"),
        .package(path: "../swift-ordinal-primitives"),
        .package(path: "../swift-cardinal-primitives"),
    ],
    targets: [
        // Internal: Core types with ~Copyable support (type declarations only)
        .target(
            name: "Set Primitives Core",
            dependencies: [
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
                .product(name: "Bit Primitives", package: "swift-bit-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
                .product(name: "Hash Table Primitives", package: "swift-hash-table-primitives"),
                .product(name: "Storage Primitives", package: "swift-storage-primitives"),
                .product(name: "Buffer Primitives", package: "swift-buffer-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
            ]
        ),
        // Internal: Set.Ordered functionality
        .target(
            name: "Set Ordered Primitives",
            dependencies: [
                "Set Primitives Core",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),
                .product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Storage Primitives", package: "swift-storage-primitives"),
                .product(name: "Hash Table Primitives", package: "swift-hash-table-primitives"),
                .product(name: "Buffer Primitives", package: "swift-buffer-primitives"),
            ],
            exclude: [
                "Set.Ordered+Sequence.Consume.swift",
                "Set.Ordered+Sequence.Drain.swift",
                "Set.Ordered.Fixed+Sequence.Consume.swift",
                "Set.Ordered.Fixed+Sequence.Drain.swift",
                "Set.Ordered.Static+Sequence.Consume.swift",
                "Set.Ordered.Static+Sequence.Drain.swift",
                "Set.Ordered.Small+Sequence.Consume.swift",
                "Set.Ordered.Small+Sequence.Drain.swift",
            ]
        ),
        // Public: Re-exports all modules for users
        .target(
            name: "Set Primitives",
            dependencies: [
                "Set Primitives Core",
                "Set Ordered Primitives",
            ]
        ),
        // Test Support: Re-exports test support from dependencies
        .target(
            name: "Set Primitives Test Support",
            dependencies: [
                .product(name: "Bit Primitives Test Support", package: "swift-bit-primitives"),
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "Set Primitives Tests",
            dependencies: [
                "Set Primitives",
                "Set Primitives Test Support",
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety()
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
