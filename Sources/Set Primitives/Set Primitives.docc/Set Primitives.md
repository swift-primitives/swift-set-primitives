# ``Set_Primitives``

@Metadata {
    @DisplayName("Set Primitives")
    @TitleHeading("Swift Primitives")
}

The insertion-ordered hash set ``Set`` and the ``Set/`Protocol``` membership
contract that every set discipline conforms to.

## Overview

`Set_Primitives` ships ``Set`` — an insertion-ordered hash set generic over its
storage **column** — together with the `Set` namespace and the ``Set/`Protocol```
membership contract. `Set<S>` stores members densely in insertion order behind a
bucket position-index engine, so `contains` and `insert` are O(1) average-case and
`forEach` follows insertion order. Copyability flows from the column: a move-only
ordered-hashed column is zero-cost, and a `Shared` column gives copy-on-write value
semantics.

The ``Set/`Protocol``` contract is **membership-only** — `contains` and `count`
over an `Element` constrained to `Hash.Protocol` (element iteration is hosted on
`Iterable`, not here). The relational and constructive algebra over conformers —
`isSubset`, `isSuperset`, `isDisjoint`, `union`, `intersection`, … — lives in
`swift-set-algebra-primitives`, which composes over any `Set.Protocol & Iterable`
conformer. The order-preserving discipline with positional access, `Set.Ordered`,
lives in `swift-set-ordered-primitives`.

Set disciplines support `~Copyable` elements — the namespace constrains
`Element: ~Copyable`, and the membership contract carries the constraint forward as
`Element: Hash.Protocol & ~Copyable`.

## Topics

### Scope

- <doc:Set-Primitives-Scope>

### The Set ADT

- ``Set``

### Membership Contract

- ``Set/`Protocol```
- ``Set/Index``
