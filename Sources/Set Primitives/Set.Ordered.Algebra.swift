// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - Algebra Accessor

extension Set.Ordered {
    /// Nested accessor for set algebra operations.
    ///
    /// ```swift
    /// let union = a.algebra.union(b)
    /// let intersection = a.algebra.intersection(b)
    /// let difference = a.algebra.subtract(b)
    /// let symmetric = a.algebra.symmetric.difference(b)
    /// ```
    @inlinable
    public var algebra: Algebra {
        Algebra(set: self)
    }
}

// MARK: - Algebra Type

extension Set.Ordered {
    /// Namespace for set algebra operations.
    public struct Algebra {
        @usableFromInline
        let set: Set<Element>.Ordered

        @usableFromInline
        init(set: Set<Element>.Ordered) {
            self.set = set
        }
    }
}

// MARK: - Algebra Operations

extension Set.Ordered.Algebra {
    /// Returns a new set with elements from both sets.
    ///
    /// Elements from `self` come first in their original order,
    /// followed by elements from `other` that are not in `self`.
    ///
    /// - Parameter other: The set to form a union with.
    /// - Returns: A new set containing all elements from both sets.
    /// - Complexity: O(n + m) where n and m are the sizes of the sets.
    @inlinable
    public func union(_ other: Set<Element>.Ordered) -> Set<Element>.Ordered {
        var result = set
        for element in other {
            result.insert(element)
        }
        return result
    }

    /// Returns a new set with elements common to both sets.
    ///
    /// The order is preserved from `self`.
    ///
    /// - Parameter other: The set to intersect with.
    /// - Returns: A new set containing only elements present in both sets.
    /// - Complexity: O(n) where n is the size of `self`.
    @inlinable
    public func intersection(_ other: Set<Element>.Ordered) -> Set<Element>.Ordered {
        var result = Set<Element>.Ordered()
        for element in set {
            if other.contains(element) {
                result.insert(element)
            }
        }
        return result
    }

    /// Returns a new set with elements in `self` that are not in `other`.
    ///
    /// The order is preserved from `self`.
    ///
    /// - Parameter other: The set to subtract.
    /// - Returns: A new set with elements not in `other`.
    /// - Complexity: O(n) where n is the size of `self`.
    @inlinable
    public func subtract(_ other: Set<Element>.Ordered) -> Set<Element>.Ordered {
        var result = Set<Element>.Ordered()
        for element in set {
            if !other.contains(element) {
                result.insert(element)
            }
        }
        return result
    }

    /// Nested accessor for symmetric operations.
    @inlinable
    public var symmetric: Symmetric {
        Symmetric(set: set)
    }
}

// MARK: - Mutating Algebra Operations

extension Set.Ordered {
    /// Adds elements from another set.
    ///
    /// - Parameter other: The set to form a union with.
    @inlinable
    public mutating func form(_ operation: (Algebra) -> Set<Element>.Ordered) {
        self = operation(algebra)
    }
}
