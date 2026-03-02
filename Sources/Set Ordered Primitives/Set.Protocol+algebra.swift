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

// MARK: - Algebra Defaults (Non-Mutating)
//
// These defaults provide set algebra operations for ALL Set.Protocol conformers.
// Each operation composes from `forEach` + `contains` (protocol requirements)
// and constructs a `Set.Ordered` result.
//
// Returns `Set.Ordered` (not `Self`) because:
// - Result size is unpredictable for bounded variants (Fixed, Static)
// - Set.Ordered is the natural growable container
// - Conformers can override with Self-returning versions if appropriate
//
// Module placement: Set Ordered Primitives (not Set Primitives Core) because
// these defaults construct Set.Ordered instances and call insert.

public import Set_Primitives_Core

extension Set.`Protocol` where Self: ~Copyable, Element: Copyable {
    /// Returns a new set with elements from both sets.
    ///
    /// Elements from `self` appear first in insertion order,
    /// followed by elements from `other` not already present.
    ///
    /// - Parameter other: The set to form a union with.
    /// - Returns: A new ordered set containing all elements from both sets.
    /// - Complexity: O(n + m) average, where n and m are the set sizes.
    @inlinable
    public func union<Other: Set.`Protocol` & ~Copyable>(
        _ other: borrowing Other
    ) -> Set<Element>.Ordered where Other.Element == Element {
        var result = Set<Element>.Ordered()
        self.forEach { element in result.insert(element) }
        other.forEach { element in result.insert(element) }
        return result
    }

    /// Returns a new set with elements common to both sets.
    ///
    /// Iterates the smaller set and probes the larger for O(min(n,m)) average.
    ///
    /// - Parameter other: The set to intersect with.
    /// - Returns: A new ordered set containing only elements present in both sets.
    /// - Complexity: O(min(n, m)) average, where n and m are the set sizes.
    @inlinable
    public func intersection<Other: Set.`Protocol` & ~Copyable>(
        _ other: borrowing Other
    ) -> Set<Element>.Ordered where Other.Element == Element {
        var result = Set<Element>.Ordered()
        if count <= other.count {
            self.forEach { element in
                if other.contains(element) { result.insert(element) }
            }
        } else {
            other.forEach { element in
                if self.contains(element) { result.insert(element) }
            }
        }
        return result
    }

    /// Returns a new set with elements in this set that are not in `other`.
    ///
    /// Elements appear in the iteration order of `self`.
    ///
    /// - Parameter other: The set to subtract.
    /// - Returns: A new ordered set with elements not in `other`.
    /// - Complexity: O(n) average, where n is the size of this set.
    @inlinable
    public func subtract<Other: Set.`Protocol` & ~Copyable>(
        _ other: borrowing Other
    ) -> Set<Element>.Ordered where Other.Element == Element {
        var result = Set<Element>.Ordered()
        self.forEach { element in
            if !other.contains(element) { result.insert(element) }
        }
        return result
    }

    /// Returns a new set with elements in either set, but not both.
    ///
    /// Elements from `self` appear first, followed by elements from `other`.
    ///
    /// - Parameter other: The other set.
    /// - Returns: A new ordered set with elements in exactly one of the sets.
    /// - Complexity: O(n + m) average, where n and m are the set sizes.
    @inlinable
    public func symmetricDifference<Other: Set.`Protocol` & ~Copyable>(
        _ other: borrowing Other
    ) -> Set<Element>.Ordered where Other.Element == Element {
        var result = Set<Element>.Ordered()
        self.forEach { element in
            if !other.contains(element) { result.insert(element) }
        }
        other.forEach { element in
            if !self.contains(element) { result.insert(element) }
        }
        return result
    }
}
