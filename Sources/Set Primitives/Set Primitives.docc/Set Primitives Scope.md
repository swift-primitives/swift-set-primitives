# Set Primitives Scope

What `swift-set-primitives` is, and what it deliberately leaves to other packages.

## Identity

`swift-set-primitives` ships the **insertion-ordered hash set** — the base set ADT,
the bound-free carrier `__Set<S>` generic over its storage column with the canonical
front door `Set<E>` ([DS-028]) — together with the `Set` namespace and the
`Set.Protocol` membership contract (`contains` + `count`). It answers both *"what is a
set?"* (the membership vocabulary) and *"the default set"* (the front door `Set<E>`);
*how* a set is stored is chosen by the column type parameter, not by a sibling type.

## Core targets

- **Set Primitive** — the `__Set<S>` carrier, the `Set<E>` front door, their
  column-pinned constructors, and the root `Set` namespace.
- **Set Protocol Primitives** — the `Set.Protocol` membership contract (`contains` +
  `count`) and `Set.Index`.
- **Set Primitives** — the umbrella re-exporting the above.

## Out of scope

- **Relational and constructive algebra** — `isSubset` / `isSuperset` / `isDisjoint` /
  `union` / `intersection` / `subtracting`, defined over any `Set.Protocol & Iterable`
  conformer → `swift-set-algebra-primitives`.
- **The order-preserving discipline** — `Set.Ordered` (positional access into insertion
  order) and its `Sequence` / `Collection` conformances → `swift-set-ordered-primitives`.
- **Future hash / unordered disciplines** — any further set discipline extends this
  namespace from its own sibling package, the same way the ordered discipline does.

## Evaluation rule

`__Set<S>` is column-generic: capacity and ownership policy are the column's business, not
a sibling `Set` subtype (the variant doctrine). A proposal that adds a capacity variant as
a new `Set` type, or a relational / constructive algebra operation here, is out of scope —
the former belongs in the column vocabulary, the latter in `swift-set-algebra-primitives`.
