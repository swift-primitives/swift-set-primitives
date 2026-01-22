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
        .package(path: "../swift-collection-primitives"),
    ],
    targets: [
        // Internal: Core types with ~Copyable support (no Sequence/Collection.Protocol conformances)
        .target(
            name: "Set Primitives Core",
            dependencies: [
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
                .product(name: "Bit Primitives", package: "swift-bit-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
                .product(name: "Hash Table Primitives", package: "swift-hash-table-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),
        // Internal: Sequence/Collection.Protocol conformances (Element: Copyable)
        // Separate module to avoid constraint poisoning on Core types
        .target(
            name: "Set Primitives Sequence",
            dependencies: [
                "Set Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),
        // Public: Re-exports Core and Sequence for users
        .target(
            name: "Set Primitives",
            dependencies: [
                "Set Primitives Core",
                "Set Primitives Sequence",
            ]
        ),
        .testTarget(
            name: "Set Primitives Tests",
            dependencies: ["Set Primitives"]
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
