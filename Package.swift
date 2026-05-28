// swift-tools-version: 6.3.1

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
        // MARK: - Namespace
        .library(
            name: "Set Primitive",
            targets: ["Set Primitive"]
        ),

        // MARK: - Protocol
        .library(
            name: "Set Protocol Primitives",
            targets: ["Set Protocol Primitives"]
        ),

        // MARK: - Umbrella
        .library(
            name: "Set Primitives",
            targets: ["Set Primitives"]
        ),

        // MARK: - Test Support
        .library(
            name: "Set Primitives Test Support",
            targets: ["Set Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-hash-primitives"),
    ],
    targets: [

        // MARK: - Namespace (singular root: `enum Set`; zero external deps per [MOD-017])
        .target(
            name: "Set Primitive",
            dependencies: []
        ),

        // MARK: - Protocol (Set.Protocol membership contract + Set.Index + relational defaults)
        .target(
            name: "Set Protocol Primitives",
            dependencies: [
                "Set Primitive",
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),

        // MARK: - Umbrella
        .target(
            name: "Set Primitives",
            dependencies: [
                "Set Primitive",
                "Set Protocol Primitives",
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "Set Primitives Test Support",
            dependencies: [
                "Set Primitives",
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
        .testTarget(
            name: "Set Protocol Primitives Tests",
            dependencies: [
                "Set Protocol Primitives",
                "Set Primitives Test Support",
            ],
            path: "Tests/Set Protocol Primitives Tests"
        ),
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
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
