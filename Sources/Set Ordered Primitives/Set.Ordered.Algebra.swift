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

import Index_Primitives
public import Set_Primitives_Core
public import Buffer_Linear_Primitive

// MARK: - Algebra Accessor

extension Set_Primitives_Core.Set.Ordered where Element: Copyable {
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
        Algebra(buffer: buffer, hashTable: hashTable)
    }
}

// MARK: - Algebra Type

extension Set_Primitives_Core.Set.Ordered where Element: Copyable {
    /// Namespace for set algebra operations.
    ///
    /// Algebra operations require `Element: Copyable` since they create new sets
    /// and copy elements between sets.
    ///
    /// Note: This stores the Buffer.Linear (a CoW value type) rather than
    /// the Set.Ordered directly (which would require consuming or mutation).
    public struct Algebra {
        @usableFromInline
        let buffer: Buffer<Element>.Linear

        @usableFromInline
        let hashTable: Hash.Table<Element>

        @usableFromInline
        init(buffer: Buffer<Element>.Linear, hashTable: Hash.Table<Element>) {
            self.buffer = buffer
            self.hashTable = hashTable
        }

        @usableFromInline
        var count: Index<Element>.Count { buffer.count }
    }
}

// MARK: - Algebra Operations

extension Set_Primitives_Core.Set.Ordered.Algebra {
    /// Returns a new set with elements from both sets.
    ///
    /// Elements from `self` come first in their original order,
    /// followed by elements from `other` that are not in `self`.
    ///
    /// - Parameter other: The set to form a union with.
    /// - Returns: A new set containing all elements from both sets.
    /// - Complexity: O(n + m) where n and m are the sizes of the sets.
    @inlinable
    public func union(_ other: borrowing Set_Primitives_Core.Set<Element>.Ordered) -> Set_Primitives_Core.Set<Element>.Ordered {
        var result = Set_Primitives_Core.Set<Element>.Ordered()
        // Add elements from self
        var index: Index<Element> = .zero
        let end = count.map(Ordinal.init)
        while index < end {
            result.insert(buffer[index])
            index += .one
        }
        // Add elements from other
        var otherIndex: Index<Element> = .zero
        let otherEnd = other.count.map(Ordinal.init)
        while otherIndex < otherEnd {
            result.insert(other.buffer[otherIndex])
            otherIndex += .one
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
    public func intersection(_ other: borrowing Set_Primitives_Core.Set<Element>.Ordered) -> Set_Primitives_Core.Set<Element>.Ordered {
        var result = Set_Primitives_Core.Set<Element>.Ordered()
        var index: Index<Element> = .zero
        let end = count.map(Ordinal.init)
        while index < end {
            let element = buffer[index]
            if other.contains(element) {
                result.insert(element)
            }
            index += .one
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
    public func subtract(_ other: borrowing Set_Primitives_Core.Set<Element>.Ordered) -> Set_Primitives_Core.Set<Element>.Ordered {
        var result = Set_Primitives_Core.Set<Element>.Ordered()
        var index: Index<Element> = .zero
        let end = count.map(Ordinal.init)
        while index < end {
            let element = buffer[index]
            if !other.contains(element) {
                result.insert(element)
            }
            index += .one
        }
        return result
    }

    /// Nested accessor for symmetric operations.
    @inlinable
    public var symmetric: Symmetric {
        Symmetric(buffer: buffer, hashTable: hashTable)
    }
}

// MARK: - Mutating Algebra Operations

extension Set_Primitives_Core.Set.Ordered where Element: Copyable {
    /// Applies an algebra operation and replaces self with the result.
    ///
    /// - Parameter operation: A closure that takes the algebra accessor and returns a new set.
    @inlinable
    public mutating func form(_ operation: (Algebra) -> Set_Primitives_Core.Set<Element>.Ordered) {
        self = operation(algebra)
    }
}
