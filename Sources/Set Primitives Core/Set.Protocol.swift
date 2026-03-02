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
public protocol __SetProtocol: ~Copyable {
    /// The type of element stored in the set.
    associatedtype Element: Hash.`Protocol` & ~Copyable

    /// Returns whether the set contains the given element.
    func contains(_ element: borrowing Element) -> Bool

    /// Calls `body` with a borrowing reference to each element.
    func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)
}

// MARK: - Namespace Typealias

extension Set where Element: ~Copyable {
    /// Protocol unifying membership queries across all `Set` variants.
    ///
    /// `Set.Protocol` refines nothing — it declares `contains` and `forEach`
    /// as requirements, enabling default implementations for `isDisjoint`,
    /// `isSubset`, and `isSuperset`.
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
