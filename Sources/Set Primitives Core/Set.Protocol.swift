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

// MARK: - Set.Protocol (Hoisted as __SetProtocol)

/// Protocol unifying membership queries across all Set variants.
///
/// See ``Set/`Protocol``` for documentation.
///
/// ## Probe finding (2026-05-28) — family-protocol `Backing` lift is NOT expressible
///
/// The handoff's family-protocol lean — *"a `Backing` associated type carries
/// `makeIterator` delegation once (collapses per-variant repetition)"* — was
/// attempted on this protocol and REVERTED. In current Swift (6.3.1+) a
/// protocol-extension default referencing `backing.makeIterator()` (route 1,
/// route 3) or `backing.span` (Memory.Contiguous substrate) cannot thread the
/// iterator/span lifetime back to `self` through a generic `var backing:
/// Backing` accessor: the compiler rejects with "lifetime-dependent value
/// escapes its scope." Neither plain `{ get }` nor `{ borrowing get }`
/// resolves it. Route 2 (Sequenceable consuming makeIterator) fails for a
/// separate reason — `@_lifetime(copy self)` is rejected for Escapable
/// `Iterator`, omitting it fails for `~Escapable` `Iterator`, and generic
/// context cannot witness both shapes with one signature.
///
/// Consequence: variants implement iteration per-variant (the current shape).
/// See the probe research note `swift-institute/Research/iteration-architecture-set-probe.md`
/// for the full finding + the buffer-linear-side route-3 gap.
public protocol __SetProtocol: ~Copyable {
    /// The type of element stored in the set.
    associatedtype Element: Hash.`Protocol` & ~Copyable

    /// Returns whether the set contains the given element.
    func contains(_ element: borrowing Element) -> Bool

    /// Calls `body` with a borrowing reference to each element.
    func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)

    /// The number of elements in the set.
    var count: Index<Element>.Count { get }
}

// MARK: - Namespace Typealias

extension Set where Element: ~Copyable {
    /// Protocol unifying membership queries across all `Set` variants.
    ///
    /// `Set.Protocol` refines nothing — it declares `contains`, `forEach`,
    /// and `count` as requirements, enabling default implementations for
    /// relational operations (`isDisjoint`, `isSubset`, `isSuperset`,
    /// `isStrictSubset`, `isStrictSuperset`, `isEmpty`, `isEqual`) and
    /// non-mutating algebra (`union`, `intersection`, `subtract`,
    /// `symmetricDifference`).
    ///
    /// ## Hoisted Protocol Pattern
    ///
    /// Swift does not allow nesting a protocol inside a generic type. This protocol
    /// is declared at module scope as `__SetProtocol` and aliased via:
    ///
    /// ```swift
    /// extension Set where Element: ~Copyable {
    ///     public typealias `Protocol` = __SetProtocol
    /// }
    /// ```
    ///
    /// ## Key Enabler
    ///
    /// `associatedtype Element: ~Copyable` is enabled by the `SuppressedAssociatedTypes`
    /// experimental feature flag.
    ///
    /// ## Generic Usage
    ///
    /// ```swift
    /// func overlap<A: Set.Protocol, B: Set.Protocol & ~Copyable>(
    ///     _ a: borrowing A, _ b: borrowing B
    /// ) -> Bool where A.Element == B.Element, A.Element: Copyable {
    ///     !a.isDisjoint(with: b)
    /// }
    /// ```
    public typealias `Protocol` = __SetProtocol
}
