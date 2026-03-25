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
        ),
        .library(
            name: "Set Primitives Test Support",
            targets: ["Set Primitives Test Support"]
        ),
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
        .package(path: "../swift-finite-primitives"),
    ],
    targets: [

        // MARK: - Core
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

        // MARK: - Ordered
        .target(
            name: "Set Ordered Primitives",
            dependencies: [
                "Set Primitives Core",
                .product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),
                .product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
            ],
            exclude: [
            ]
        ),

        // MARK: - Umbrella
        .target(
            name: "Set Primitives",
            dependencies: [
                "Set Primitives Core",
                "Set Ordered Primitives",
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "Set Primitives Test Support",
            dependencies: [
                .product(name: "Bit Primitives Test Support", package: "swift-bit-primitives"),
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
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
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
