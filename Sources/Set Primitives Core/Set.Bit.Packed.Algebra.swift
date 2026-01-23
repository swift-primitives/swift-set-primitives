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

public import Bit_Primitives

// MARK: - Algebra Accessor

extension Set<Bit>.Packed {
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
        Algebra(storage: storage, capacity: storedCapacity)
    }
}

// MARK: - Algebra Type

extension Set<Bit>.Packed {
    /// Namespace for set algebra operations.
    public struct Algebra: Sendable {
        @usableFromInline
        let storage: ContiguousArray<UInt>

        @usableFromInline
        let capacity: Int

        @usableFromInline
        static var bitsPerWord: Int { UInt.bitWidth }

        @usableFromInline
        init(storage: ContiguousArray<UInt>, capacity: Int) {
            self.storage = storage
            self.capacity = capacity
        }

        @usableFromInline
        var wordCount: Int { storage.count }
    }
}

// MARK: - Algebra Operations

extension Set<Bit>.Packed.Algebra {
    /// Returns a new set with elements from both sets.
    ///
    /// - Parameter other: The set to form a union with.
    /// - Returns: A new set containing all elements from both sets.
    /// - Complexity: O(n) where n is the number of words.
    @inlinable
    public func union(_ other: Set<Bit>.Packed) -> Set<Bit>.Packed {
        var resultStorage = storage
        var resultCapacity = capacity

        if other.storedCapacity > capacity {
            let newCapacity = other.storedCapacity
            let newWordCount = (newCapacity + Self.bitsPerWord - 1) / Self.bitsPerWord
            let oldWordCount = resultStorage.count

            if newWordCount > oldWordCount {
                resultStorage.reserveCapacity(newWordCount)
                for _ in oldWordCount..<newWordCount {
                    resultStorage.append(0)
                }
            }
            resultCapacity = newCapacity
        }

        let minWords = Swift.min(resultStorage.count, other.storage.count)
        for i in 0..<minWords {
            resultStorage[i] |= other.storage[i]
        }

        return Set<Bit>.Packed(__storage: resultStorage, capacity: resultCapacity)
    }

    /// Returns a new set with elements common to both sets.
    ///
    /// - Parameter other: The set to intersect with.
    /// - Returns: A new set containing only elements present in both sets.
    /// - Complexity: O(n) where n is the number of words.
    @inlinable
    public func intersection(_ other: Set<Bit>.Packed) -> Set<Bit>.Packed {
        var resultStorage = storage

        let minWords = Swift.min(resultStorage.count, other.storage.count)
        for i in 0..<minWords {
            resultStorage[i] &= other.storage[i]
        }
        for i in minWords..<resultStorage.count {
            resultStorage[i] = 0
        }

        return Set<Bit>.Packed(__storage: resultStorage, capacity: capacity)
    }

    /// Returns a new set with elements in self but not in other.
    ///
    /// - Parameter other: The set to subtract.
    /// - Returns: A new set with elements not in other.
    /// - Complexity: O(n) where n is the number of words.
    @inlinable
    public func subtract(_ other: Set<Bit>.Packed) -> Set<Bit>.Packed {
        var resultStorage = storage

        let minWords = Swift.min(resultStorage.count, other.storage.count)
        for i in 0..<minWords {
            resultStorage[i] &= ~other.storage[i]
        }

        return Set<Bit>.Packed(__storage: resultStorage, capacity: capacity)
    }

    /// Nested accessor for symmetric operations.
    @inlinable
    public var symmetric: Symmetric {
        Symmetric(storage: storage, capacity: capacity)
    }
}

// MARK: - Mutating Algebra Operations

extension Set<Bit>.Packed {
    /// Applies an algebra operation and replaces self with the result.
    ///
    /// - Parameter operation: A closure that takes the algebra accessor and returns a new set.
    @inlinable
    public mutating func form(_ operation: (Algebra) -> Set<Bit>.Packed) {
        self = operation(algebra)
    }
}
