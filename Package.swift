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
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-hash-primitives.git", branch: "main"),
        // NOTE: the iteration concern (swift-iterator-primitives) is NOT a
        // dependency. It moved out with the Set Algebra target to
        // swift-set-algebra-primitives ([MOD-029] prune); the membership core +
        // the BuildableSet refinement are iteration-free.
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

        // MARK: - Umbrella (NB: no Set Algebra re-export — lifted to
        // swift-set-algebra-primitives; re-exporting it here would complete a
        // package cycle, [MOD-032]/[MOD-033] cursor-pilot drop)
        .target(
            name: "Set Primitives",
            dependencies: [
                "Set Primitive",
                "Set Protocol Primitives",
                "Set Buildable Protocol Primitives",
            ]
        ),

        // MARK: - Test Support ([MOD-024] empty shell — the conformer fixture +
        // the relational-default tests moved to swift-set-algebra-primitives)
        .target(
            name: "Set Primitives Test Support",
            dependencies: [
                "Set Primitives",
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
            ],
            path: "Tests/Support"
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
