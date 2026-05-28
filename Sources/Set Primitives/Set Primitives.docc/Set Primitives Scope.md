# Set Primitives Scope

What `swift-set-primitives` is, and what it deliberately leaves to other packages.

## Identity

`swift-set-primitives` provides the **set vocabulary**: the root `Set`
namespace and the `Set.Protocol` membership contract — the
membership-uniqueness abstraction (`contains`, `forEach`, `count`) plus the
relational algebra (`isDisjoint`, `isSubset`, `isSuperset`, `isStrictSubset`,
`isStrictSuperset`, `isEmpty`, `isEqual`) that follows from it. It is the answer
to *"what is a set?"*, expressed independently of *"how is a set stored?"*. It
owns no storage.

## Core targets

- **Set Primitive** — the root `enum Set` namespace (zero external dependencies).
- **Set Protocol Primitives** — the `Set.Protocol` membership contract,
  `Set.Index`, and the relational default implementations.
- **Set Primitives** — the umbrella re-exporting the above.

## Out of scope

- **Storage / ordered disciplines** — the insertion-order-preserving
  `Set.Ordered` and its `Fixed` / `Static` / `Small` capacity variants, with
  their `Buffer.Linear` + `Hash.Table` coordination, set-producing algebra
  (`union` / `intersection` / `subtract` / `symmetricDifference`), and
  `Sequence` / `Collection` conformances → `swift-set-ordered-primitives`.
- **Future hash / unordered disciplines** — any unordered or hash-only set
  storage discipline extends this namespace from its own sibling package, the
  same way the ordered discipline does. It does not land here.

## Evaluation rule

Additions are evaluated against this scope. A proposal that introduces a
storage discipline, a storage-bound operation, or a conformance that constrains
elements beyond the membership contract is out of scope — it belongs in a
sibling discipline package that extends the `Set` namespace, not in this one.
