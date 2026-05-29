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

        // MARK: - Buildable Protocol (growable-set refinement)
        .library(
            name: "Set Buildable Protocol Primitives",
            targets: ["Set Buildable Protocol Primitives"]
        ),

        // MARK: - Algebra (orthogonal predicates + constructive defaults)
        .library(
            name: "Set Algebra Primitives",
            targets: ["Set Algebra Primitives"]
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
        // Iteration concern — consumed ONLY by the Set Algebra target (the
        // membership core stays iteration-free). Tier-safe downward edge.
        .package(path: "../swift-iterator-primitives"),
    ],
    targets: [

        // MARK: - Namespace (singular root: `enum Set`; zero external deps per [MOD-017])
        .target(
            name: "Set Primitive",
            dependencies: []
        ),

        // MARK: - Protocol (Set.Protocol membership CORE: {contains, count} + Set.Index + isEmpty)
        .target(
            name: "Set Protocol Primitives",
            dependencies: [
                "Set Primitive",
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),

        // MARK: - Buildable Protocol (Set.Buildable.Protocol: init + insert; growable refinement)
        .target(
            name: "Set Buildable Protocol Primitives",
            dependencies: [
                "Set Protocol Primitives",
            ]
        ),

        // MARK: - Algebra (orthogonal predicates + constructive defaults; the lone iterator edge)
        .target(
            name: "Set Algebra Primitives",
            dependencies: [
                "Set Protocol Primitives",
                "Set Buildable Protocol Primitives",
                .product(name: "Iterable", package: "swift-iterator-primitives"),
            ]
        ),

        // MARK: - Umbrella
        .target(
            name: "Set Primitives",
            dependencies: [
                "Set Primitive",
                "Set Protocol Primitives",
                "Set Buildable Protocol Primitives",
                "Set Algebra Primitives",
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "Set Primitives Test Support",
            dependencies: [
                "Set Primitives",
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
                // TS-of-dep ([MOD-024]): surfaces Iterator.Chunk so Set.Fixture
                // conforms Iterable (iterator-primitives is a product dep of the
                // Set Algebra target).
                .product(name: "Iterator Primitives Test Support", package: "swift-iterator-primitives"),
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
