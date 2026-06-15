# Set Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)
[![CI](https://github.com/swift-primitives/swift-set-primitives/actions/workflows/ci.yml/badge.svg)](https://github.com/swift-primitives/swift-set-primitives/actions/workflows/ci.yml)

`Set<S>` — an insertion-ordered hash set generic over its storage **column**. Members live densely in insertion order behind a bucket position-index engine, so `contains` and `insert` are O(1) average-case and iteration follows insertion order. As with the rest of the family, copyability flows from the column: a move-only ordered-hashed column is zero-cost, and a `Shared` column gives copy-on-write value semantics.

The package also defines the `Set` namespace and the `Set.Protocol` membership contract — the `contains` + `count` vocabulary any set discipline conforms to. Relational and constructive algebra over conformers (`isSubset`, `union`, `intersection`, …) lives in the sibling set-algebra package; the order-preserving discipline with positional access lives in the set-ordered package.

---

## Key Features

- **Insertion-ordered hash set** — O(1) average-case `contains` and `insert`; `forEach` follows insertion order.
- **Column-generic storage** — `Set<S>` composes the ordered-hashed column; the backing is a type parameter, not a separate type per policy.
- **Copyability from the column** — move-only by default (zero-cost), opt-in copy-on-write via a `Shared` column.
- **Membership vocabulary** — `Set.Protocol` (`contains` + `count`) that any type can satisfy, so set algebra composes over your own conformers.

---

## Quick Start

```swift
import Set_Primitives
import Column_Primitives
import Hash_Indexed_Primitive
import Hash_Primitives_Standard_Library_Integration

// Move-only by default, over the ordered-hashed column:
var seen = Set<Hash.Indexed<Column.Heap<Int>>>()
seen.insert(200)
seen.insert(404)
seen.insert(200)                       // already present — ignored
let hasError = seen.contains(404)      // true
seen.forEach { print($0) }             // 200, 404 — insertion order
```

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-set-primitives.git", branch: "main")
]
```

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "Set Primitives", package: "swift-set-primitives")
    ]
)
```

The package is pre-1.0 — depend on `branch: "main"` until `0.1.0` is tagged. Requires Swift 6.3 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the corresponding Linux / Windows toolchain).

---

## Architecture

| Product | Contents | When to import |
|---------|----------|----------------|
| `Set Primitives` | Umbrella — `Set<S>`, the column constructors, the `Set.Protocol` contract, and the conformances | Most consumers |
| `Set Primitive` | The `Set<S>` value type and its column-pinned surface, without the conformances | Move-only / minimal-surface use |
| `Set Protocol Primitives` | The `Set.Protocol` membership contract (`contains` + `count`) | Authoring a set discipline |

---

## Platform Support

| Platform         | CI  | Status       |
|------------------|-----|--------------|
| macOS 26         | Yes | Full support |
| Linux            | Yes | Full support |
| Windows          | Yes | Full support |
| iOS/tvOS/watchOS | —   | Supported    |
| Swift Embedded   | —   | Pending (nightly-toolchain follow-up) |

---

## Related Packages

- [`swift-set-algebra-primitives`](https://github.com/swift-primitives/swift-set-algebra-primitives) — relational and constructive algebra (`isSubset`, `union`, `intersection`, …) over any `Set.Protocol` conformer.
- [`swift-set-ordered-primitives`](https://github.com/swift-primitives/swift-set-ordered-primitives) — the order-preserving `Set.Ordered` discipline with positional access.
- [`swift-hash-primitives`](https://github.com/swift-primitives/swift-hash-primitives) — the `Hash.Key` element-hashing contract set elements conform to.
- [`swift-column-primitives`](https://github.com/swift-primitives/swift-column-primitives) — the column vocabulary (`Hash.Indexed`, `Column.Heap`, …) the set composes.

---

## Community

<!-- BEGIN: discussion -->
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
