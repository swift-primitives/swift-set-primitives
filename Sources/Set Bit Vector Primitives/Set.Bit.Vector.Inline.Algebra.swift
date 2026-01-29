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

public import Set_Primitives_Core
public import Bit_Primitives

// MARK: - Algebra Accessor

extension Set<Bit>.Vector.Inline {
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
        Algebra(storage: storage)
    }
}

// MARK: - Algebra Type

extension Set<Bit>.Vector.Inline {
    /// Namespace for set algebra operations.
    public struct Algebra: Sendable {
        @usableFromInline
        let storage: InlineArray<wordCount, UInt>

        @usableFromInline
        static var bitsPerWord: Int { UInt.bitWidth }

        @usableFromInline
        init(storage: InlineArray<wordCount, UInt>) {
            self.storage = storage
        }
    }
}

// MARK: - Algebra Operations

extension Set<Bit>.Vector.Inline.Algebra {
    /// Returns a new set with elements from both sets.
    ///
    /// - Parameter other: The set to form a union with.
    /// - Returns: A new set containing all elements from both sets.
    @inlinable
    public func union(_ other: Set<Bit>.Vector.Inline<wordCount>) -> Set<Bit>.Vector.Inline<wordCount> {
        var resultStorage = storage
        for i in 0..<wordCount {
            resultStorage[i] |= other.storage[i]
        }
        return Set<Bit>.Vector.Inline<wordCount>(__storage: resultStorage)
    }

    /// Returns a new set with elements common to both sets.
    ///
    /// - Parameter other: The set to intersect with.
    /// - Returns: A new set containing only elements present in both sets.
    @inlinable
    public func intersection(_ other: Set<Bit>.Vector.Inline<wordCount>) -> Set<Bit>.Vector.Inline<wordCount> {
        var resultStorage = storage
        for i in 0..<wordCount {
            resultStorage[i] &= other.storage[i]
        }
        return Set<Bit>.Vector.Inline<wordCount>(__storage: resultStorage)
    }

    /// Returns a new set with elements in self but not in other.
    ///
    /// - Parameter other: The set to subtract.
    /// - Returns: A new set with elements not in other.
    @inlinable
    public func subtract(_ other: Set<Bit>.Vector.Inline<wordCount>) -> Set<Bit>.Vector.Inline<wordCount> {
        var resultStorage = storage
        for i in 0..<wordCount {
            resultStorage[i] &= ~other.storage[i]
        }
        return Set<Bit>.Vector.Inline<wordCount>(__storage: resultStorage)
    }

    /// Nested accessor for symmetric operations.
    @inlinable
    public var symmetric: Symmetric {
        Symmetric(storage: storage)
    }
}

// MARK: - Mutating Algebra Operations

extension Set<Bit>.Vector.Inline {
    /// Applies an algebra operation and replaces self with the result.
    ///
    /// - Parameter operation: A closure that takes the algebra accessor and returns a new set.
    @inlinable
    public mutating func form(_ operation: (Algebra) -> Set<Bit>.Vector.Inline<wordCount>) {
        self = operation(algebra)
    }
}
