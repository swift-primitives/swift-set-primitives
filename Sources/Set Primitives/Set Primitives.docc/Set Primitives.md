# ``Set_Primitives``

@Metadata {
    @DisplayName("Set Primitives")
    @TitleHeading("Swift Primitives")
}

The `Set` namespace and the `Set.Protocol` membership contract that every set
discipline in the ecosystem conforms to.

## Overview

`Set_Primitives` defines *what a set is* without committing to *how a set is
stored*. It declares the root ``Set`` namespace and the ``Set/`Protocol``
membership contract — three requirements (`contains`, `forEach`, `count`) over
an `Element` constrained to `Hash.Protocol`. On top of those requirements the
package supplies the relational algebra that every set shares — `isDisjoint`,
`isSubset`, `isSuperset`, `isStrictSubset`, `isStrictSuperset`, `isEmpty`, and
`isEqual` — as default implementations, so a conformer that provides the three
requirements gets the relational surface for free.

The package owns **no storage**. Concrete storage disciplines — the
insertion-order-preserving `Set.Ordered` and its capacity variants — live in the
sibling package `swift-set-ordered-primitives`, which extends this namespace.
Future hash/unordered disciplines extend it the same way. Because the
relational defaults are written against the protocol requirements alone, they
operate uniformly across every discipline, including heterogeneous pairs (a
default such as `isSubset(of:)` accepts any other `Set.Protocol` conformer with
the same `Element`).

```swift
import Set_Primitives

func haveOverlap<A: Set.`Protocol`, B: Set.`Protocol` & ~Copyable>(
    _ a: borrowing A, _ b: borrowing B
) -> Bool where A.Element == B.Element, A.Element: Copyable {
    !a.isDisjoint(with: b)
}
```

Set disciplines in this ecosystem support `~Copyable` elements — the namespace
constrains `Element: ~Copyable`, and the membership contract carries the element
constraint forward as `Element: Hash.Protocol & ~Copyable`.

## Topics

### Scope

- <doc:Set-Primitives-Scope>

### Namespace

- ``Set``

### Membership Contract

- ``Set/`Protocol```
- ``Set/Index``

### Relational Defaults

The relational operations are default implementations on ``Set/`Protocol``.
Each takes another `Set.Protocol` conformer with a matching `Element` and
answers a membership question against the receiver:

- `isEmpty` — whether the set has no elements
- `isDisjoint(with:)` — whether two sets share no elements
- `isSubset(of:)` — whether every element is also in the other set
- `isSuperset(of:)` — whether the other set's elements are all present
- `isStrictSubset(of:)` — a subset that is strictly smaller
- `isStrictSuperset(of:)` — a superset that is strictly larger
- `isEqual(to:)` — whether both sets contain exactly the same elements
