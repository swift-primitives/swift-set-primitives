// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Hash_Primitives
public import Index_Primitives
public import Set_Primitive

// MARK: - Membership (top-level capability protocol; formerly hoisted as __SetProtocol)

/// Protocol unifying membership queries across all Set variants.
///
/// `Membership` refines nothing — it is the minimal membership *core*,
/// declaring only `contains` and `count` as requirements. From the core
/// alone it derives `isEmpty` (`count == .zero`). The set *algebra* is a
/// third orthogonal concern, composed over the core + the iteration concern
/// in `Set Algebra Primitives` (predicates `where Self: Iterable`;
/// constructive `where Self: Buildable & Iterable`, composing
/// builder-primitives' generic `Buildable` — `Initiable` + `add`) — never
/// baked into these requirements, and never a bundled `Set.Buildable.Protocol`.
///
/// ## Why this is a top-level name, not a nested `Set.Protocol`
///
/// `Set` is a [DS-028] generic front-door `typealias` (`Set.FrontDoor.swift`),
/// and Swift's member-type lookup does not look through an unbound generic
/// typealias on any toolchain (swift-institute/Issues#81). A family fronted
/// by `Set<E>` therefore has no `Set` namespace to nest a protocol into; the
/// capability protocol stays top-level, as `Iterable`, `Buildable`, and
/// `Initiable` already do. `__SetProtocol` remains as a compatibility alias
/// for this protocol.
///
/// ## Iteration is hosted on `Iterable`, not here
///
/// An earlier probe (2026-05-28) concluded a family-protocol `Backing`-lift of
/// iteration onto this protocol was "not expressible" (forcing per-variant
/// iteration). That was **overturned**: the unified family delegation IS
/// expressible via a `~Escapable` self-tied walker (the v1.3.0 re-attack). The
/// architectural resolution: **element-iteration lives on `Iterable`** (the
/// `forEach` floor + the gated pull-style `makeIterator`); `Membership`
/// unifies *membership queries* (`contains`, …) only. See
/// `swift-institute/Research/iteration-architecture-expressibility-envelope.md`
/// (v1.3.0) and `swift-institute/Research/unified-iteration-design.md`.
///
/// ## Key Enabler
///
/// `associatedtype Element: ~Copyable` is enabled by the `SuppressedAssociatedTypes`
/// experimental feature flag.
///
/// ## Generic Usage
///
/// Membership-only generic code constrains on the core alone:
///
/// ```swift
/// func has<S: Membership>(_ s: borrowing S, _ e: borrowing S.Element) -> Bool {
///     s.contains(e)
/// }
/// ```
///
/// Algebra (predicates / constructive) additionally requires the iteration
/// concern, since enumeration lives on `Iterable`:
///
/// ```swift
/// func overlap<A: Membership & Iterable, B: Membership & Iterable>(
///     _ a: borrowing A, _ b: borrowing B
/// ) -> Bool where A.Element == B.Element, A.Element: Copyable,
///                 A.Iterator.Element == A.Element, B.Iterator.Element == B.Element {
///     !a.isDisjoint(with: b)
/// }
/// ```
public protocol Membership: ~Copyable {
    /// The type of element stored in the set.
    associatedtype Element: Hash.`Protocol` & ~Copyable

    /// Returns whether the set contains the given element.
    ///
    /// The O(1) membership query — the defining set primitive (hot; concrete
    /// witness on the leaf).
    func contains(_ element: borrowing Element) -> Bool

    /// The number of elements in the set.
    ///
    /// O(1) cardinality.
    var count: Index<Element>.Count { get }
}

/// Compatibility alias retained for existing conformance sites that spell the
/// hoisted name directly.
///
/// New code should prefer ``Membership``.
public typealias __SetProtocol = Membership
