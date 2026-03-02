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

// MARK: - Default Implementations

extension Set.`Protocol` where Self: ~Copyable {
    /// Returns whether this set and `other` have no elements in common.
    ///
    /// - Parameter other: A set to test for disjointness.
    /// - Returns: `true` if this set has no elements in common with `other`.
    /// - Complexity: O(n) average, where n is the size of this set.
    @inlinable
    public func isDisjoint<Other: Set.`Protocol` & ~Copyable>(
        with other: borrowing Other
    ) -> Bool where Other.Element == Element {
        var disjoint = true
        forEach { element in
            if disjoint, other.contains(element) { disjoint = false }
        }
        return disjoint
    }

    /// Returns whether every element of this set is also in `other`.
    ///
    /// - Parameter other: A set to test against.
    /// - Returns: `true` if every element of this set is in `other`.
    /// - Complexity: O(n) average, where n is the size of this set.
    @inlinable
    public func isSubset<Other: Set.`Protocol` & ~Copyable>(
        of other: borrowing Other
    ) -> Bool where Other.Element == Element {
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
    public func isSuperset<Other: Set.`Protocol` & ~Copyable>(
        of other: borrowing Other
    ) -> Bool where Other.Element == Element {
        var result = true
        other.forEach { element in
            if result, !self.contains(element) { result = false }
        }
        return result
    }

    /// Whether the set contains no elements.
    @inlinable
    public var isEmpty: Bool { count == .zero }

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
    public func isStrictSubset<Other: Set.`Protocol` & ~Copyable>(
        of other: borrowing Other
    ) -> Bool where Other.Element == Element {
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
    public func isStrictSuperset<Other: Set.`Protocol` & ~Copyable>(
        of other: borrowing Other
    ) -> Bool where Other.Element == Element {
        count > other.count && isSuperset(of: other)
    }
}
