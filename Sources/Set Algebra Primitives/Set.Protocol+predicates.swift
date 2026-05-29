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

public import Set_Protocol_Primitives
public import Iterable

// MARK: - Relational Predicates (the algebra concern — composed `where Self: Iterable`)
//
// The relational predicates are NOT set-core requirements: they need to
// *enumerate* a set, which is the orthogonal iteration concern. They compose
// over the membership core (`contains`/`count`) + the iteration concern
// (`Iterable`'s `(borrowing Element)` `forEach` floor). Because the set
// disciplines conform `Iterable` only `where Element: Copyable`, these
// predicates attach for the Copyable-element slice; the `~Copyable`-element
// slice is gated on the iteration arc's `(borrowing Element)` floor (model
// §4.3) and is NOT landed here.
//
// `Self.Iterator.Element == Element` ties the iterator's yield to the set's
// element so `contains` typechecks against enumerated elements; `Failure ==
// Never` selects `Iterable`'s infallible `forEach`.

extension Set.`Protocol`
where Self: Iterable & ~Copyable, Self.Iterator.Element == Element, Self.Iterator.Failure == Never {

    /// Returns whether this set and `other` have no elements in common.
    ///
    /// Iterates the smaller set and probes the larger for O(min(n,m)) average.
    ///
    /// - Parameter other: A set to test for disjointness.
    /// - Returns: `true` if this set has no elements in common with `other`.
    /// - Complexity: O(min(n, m)) average, where n and m are the set sizes.
    @inlinable
    public func isDisjoint<Other: Set.`Protocol` & Iterable & ~Copyable>(
        with other: borrowing Other
    ) -> Bool
    where Other.Element == Element, Other.Iterator.Element == Element, Other.Iterator.Failure == Never {
        var disjoint = true
        if count <= other.count {
            forEach { element in
                if disjoint, other.contains(element) { disjoint = false }
            }
        } else {
            other.forEach { element in
                if disjoint, self.contains(element) { disjoint = false }
            }
        }
        return disjoint
    }

    /// Returns whether every element of this set is also in `other`.
    ///
    /// - Parameter other: A set to test against.
    /// - Returns: `true` if every element of this set is in `other`.
    /// - Complexity: O(n) average, where n is the size of this set.
    @inlinable
    public func isSubset<Other: Set.`Protocol` & Iterable & ~Copyable>(
        of other: borrowing Other
    ) -> Bool
    where Other.Element == Element, Other.Iterator.Element == Element, Other.Iterator.Failure == Never {
        var result = true
        forEach { element in
            if result, !other.contains(element) { result = false }
        }
        return result
    }

    /// Returns whether every element of `other` is also in this set.
    ///
    /// - Parameter other: A set to test against.
    /// - Returns: `true` if every element of `other` is in this set.
    /// - Complexity: O(m) average, where m is the size of `other`.
    @inlinable
    public func isSuperset<Other: Set.`Protocol` & Iterable & ~Copyable>(
        of other: borrowing Other
    ) -> Bool
    where Other.Element == Element, Other.Iterator.Element == Element, Other.Iterator.Failure == Never {
        var result = true
        other.forEach { element in
            if result, !self.contains(element) { result = false }
        }
        return result
    }

    /// Returns whether this set is a strict subset of `other`.
    ///
    /// A strict subset means every element of this set is in `other`,
    /// and `other` contains at least one element not in this set.
    ///
    /// - Parameter other: A set to test against.
    /// - Returns: `true` if this set is a strict subset of `other`.
    /// - Complexity: O(n) average, where n is the size of this set.
    ///   Short-circuits via count comparison when `count >= other.count`.
    @inlinable
    public func isStrictSubset<Other: Set.`Protocol` & Iterable & ~Copyable>(
        of other: borrowing Other
    ) -> Bool
    where Other.Element == Element, Other.Iterator.Element == Element, Other.Iterator.Failure == Never {
        count < other.count && isSubset(of: other)
    }

    /// Returns whether this set is a strict superset of `other`.
    ///
    /// A strict superset means every element of `other` is in this set,
    /// and this set contains at least one element not in `other`.
    ///
    /// - Parameter other: A set to test against.
    /// - Returns: `true` if this set is a strict superset of `other`.
    /// - Complexity: O(m) average, where m is the size of `other`.
    ///   Short-circuits via count comparison when `count <= other.count`.
    @inlinable
    public func isStrictSuperset<Other: Set.`Protocol` & Iterable & ~Copyable>(
        of other: borrowing Other
    ) -> Bool
    where Other.Element == Element, Other.Iterator.Element == Element, Other.Iterator.Failure == Never {
        count > other.count && isSuperset(of: other)
    }

    /// Returns whether this set and `other` contain the same elements.
    ///
    /// Short-circuits via count comparison — if counts differ, returns `false`
    /// without iterating. Otherwise verifies every element of `self` is in `other`.
    ///
    /// - Parameter other: A set to compare against.
    /// - Returns: `true` if both sets contain exactly the same elements.
    /// - Complexity: O(1) when counts differ; O(n) average otherwise.
    @inlinable
    public func isEqual<Other: Set.`Protocol` & Iterable & ~Copyable>(
        to other: borrowing Other
    ) -> Bool
    where Other.Element == Element, Other.Iterator.Element == Element, Other.Iterator.Failure == Never {
        count == other.count && isSubset(of: other)
    }
}
