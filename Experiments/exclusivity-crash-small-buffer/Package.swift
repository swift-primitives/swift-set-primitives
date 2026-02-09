// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "exclusivity-crash-small-buffer",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-buffer-primitives"),
        .package(path: "../../../swift-index-primitives"),
        .package(path: "../../../swift-ordinal-primitives"),
        .package(path: "../../../swift-cardinal-primitives"),
        .package(path: "../../../swift-hash-table-primitives"),
        .package(path: "../../../swift-sequence-primitives"),
        .package(path: "../../../swift-property-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "exclusivity-crash-small-buffer",
            dependencies: [
                .product(name: "Buffer Primitives", package: "swift-buffer-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),
                .product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),
                .product(name: "Hash Table Primitives", package: "swift-hash-table-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ],
            swiftSettings: [
            ]
        )
    ]
)
