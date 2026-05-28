# Set Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

The `Set` namespace and the `Set.Protocol` membership contract — the shared vocabulary every set discipline conforms to, with the relational algebra (`isSubset`, `isSuperset`, `isDisjoint`, …) supplied as defaults.

---

## Quick Start

`Set.Protocol` declares three requirements — `contains`, `forEach`, `count` — and from them derives the relational operations every set shares. Because the defaults are written against the protocol, they work across *any* two conformers with the same element, even when those conformers are different types — something `Swift.Set` cannot express:

```swift
import Set_Primitives

// A function that works over any set discipline, with no allocation,
// against a borrowed receiver and a borrowed argument of a *different* set type:
func isContainedBy<Subset: Set.`Protocol`, Superset: Set.`Protocol` & ~Copyable>(
    _ subset: borrowing Subset,
    _ superset: borrowing Superset
) -> Bool where Subset.Element == Superset.Element, Subset.Element: Copyable {
    subset.isSubset(of: superset)
}
```

A conformer supplies only the three requirements:

```swift
import Set_Primitives

struct WordSet: Set.`Protocol` {
    private let words: [String]

    func contains(_ element: borrowing String) -> Bool {
        let needle = copy element
        return words.contains(needle)
    }

    func forEach<E: Error>(_ body: (borrowing String) throws(E) -> Void) throws(E) {
        for word in words { try body(word) }
    }

    var count: Index<String>.Count {
        Index<String>.Count(Cardinal(UInt(words.count)))
    }
}

// isSubset / isSuperset / isDisjoint / isStrictSubset / isStrictSuperset /
// isEmpty / isEqual are now all available — none were written by hand.
```

Element types are constrained to the hashing contract `Hash.Protocol`, and set disciplines support `~Copyable` elements — neither of which `Swift.Set` permits.

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
        // The umbrella — namespace + membership contract + relational defaults.
        .product(name: "Set Primitives", package: "swift-set-primitives"),
        // …or, to author a discipline, depend on just the protocol target:
        // .product(name: "Set Protocol Primitives", package: "swift-set-primitives"),
    ]
)
```

The package is pre-1.0 — depend on `branch: "main"` until `0.1.0` is tagged. Requires Swift 6.3
and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the matching Linux toolchain).

---

## Products

| Product | When to import |
|---------|----------------|
| `Set Primitives` (umbrella) | Anything using the `Set` namespace, the membership contract, and the relational defaults together |
| `Set Primitive` | Sibling packages that only extend the `Set` namespace (e.g., to add a discipline) and want zero transitive weight |
| `Set Protocol Primitives` | Authoring a set discipline — the `Set.Protocol` contract, `Set.Index`, and the relational defaults |

This package owns **no storage**. It is the protocol and namespace that concrete disciplines build on; the disciplines themselves live in sibling packages (see Related Packages).

---

## Scope

The package's identity, and what it deliberately leaves to other packages, is documented in the
DocC catalog under **Set Primitives Scope**. In short: this package is the *set vocabulary* —
the `Set` namespace and the `Set.Protocol` membership-uniqueness contract plus its relational
defaults. Storage disciplines (ordered, and any future hash/unordered discipline) live in
sibling packages that extend this namespace.

---

## Related Packages

- swift-set-ordered-primitives — the insertion-order-preserving `Set.Ordered` discipline and its capacity variants, built on this namespace. *(unreleased)*
- swift-hash-primitives — the `Hash.Protocol` element-hashing contract that set elements conform to.
- swift-index-primitives — the `Index<Element>` family backing `Set.Index` and the `count` type.

---

## License

Apache License 2.0. See [LICENSE](LICENSE.md) for details.
