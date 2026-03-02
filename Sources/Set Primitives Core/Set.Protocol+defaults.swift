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
    /// - Complexity: O(min(n, m)) average, where n and m are the set sizes.
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
}
