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

extension Set<Bit>.Packed.Small {
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
        Algebra(
            inlineStorage: inlineStorage,
            heapStorage: heapStorage,
            storedCapacity: storedCapacity
        )
    }
}

// MARK: - Algebra Type

extension Set<Bit>.Packed.Small {
    /// Namespace for set algebra operations.
    public struct Algebra: Sendable {
        @usableFromInline
        let inlineStorage: InlineArray<inlineWordCount, UInt>

        @usableFromInline
        let heapStorage: ContiguousArray<UInt>?

        @usableFromInline
        let storedCapacity: Int

        @usableFromInline
        static var bitsPerWord: Int { UInt.bitWidth }

        @usableFromInline
        init(
            inlineStorage: InlineArray<inlineWordCount, UInt>,
            heapStorage: ContiguousArray<UInt>?,
            storedCapacity: Int
        ) {
            self.inlineStorage = inlineStorage
            self.heapStorage = heapStorage
            self.storedCapacity = storedCapacity
        }

        @usableFromInline
        var wordCount: Int {
            if let heapStorage = heapStorage {
                return heapStorage.count
            } else {
                return inlineWordCount
            }
        }

        @usableFromInline
        func word(at index: Int) -> UInt {
            if let heapStorage = heapStorage {
                return heapStorage[index]
            } else {
                return inlineStorage[index]
            }
        }
    }
}

// MARK: - Algebra Operations

extension Set<Bit>.Packed.Small.Algebra {
    /// Returns a new set with elements from both sets.
    ///
    /// - Parameter other: The set to form a union with.
    /// - Returns: A new set containing all elements from both sets.
    @inlinable
    public func union(_ other: Set<Bit>.Packed.Small<inlineWordCount>) -> Set<Bit>.Packed.Small<inlineWordCount> {
        var result = Set<Bit>.Packed.Small<inlineWordCount>()

        let maxCapacity = Swift.max(storedCapacity, other.storedCapacity)
        if maxCapacity > Set<Bit>.Packed.Small<inlineWordCount>.inlineCapacity {
            result.spillToHeap(toInclude: maxCapacity - 1)
        }

        let selfWordCount = wordCount
        let otherWordCount = other.wordCount
        let resultWordCount = result.wordCount

        for i in 0..<resultWordCount {
            let selfWord: UInt = i < selfWordCount ? word(at: i) : 0
            let otherWord: UInt
            if i < otherWordCount {
                if let heapStorage = other.heapStorage {
                    otherWord = heapStorage[i]
                } else {
                    otherWord = other.inlineStorage[i]
                }
            } else {
                otherWord = 0
            }

            if result.heapStorage != nil {
                result.heapStorage![i] = selfWord | otherWord
            } else {
                result.inlineStorage[i] = selfWord | otherWord
            }
        }

        return result
    }

    /// Returns a new set with elements common to both sets.
    ///
    /// - Parameter other: The set to intersect with.
    /// - Returns: A new set containing only elements present in both sets.
    @inlinable
    public func intersection(_ other: Set<Bit>.Packed.Small<inlineWordCount>) -> Set<Bit>.Packed.Small<inlineWordCount> {
        var result = Set<Bit>.Packed.Small<inlineWordCount>()

        let minWordCount = Swift.min(wordCount, other.wordCount)

        for i in 0..<minWordCount {
            let selfWord = word(at: i)
            let otherWord: UInt
            if let heapStorage = other.heapStorage {
                otherWord = heapStorage[i]
            } else {
                otherWord = other.inlineStorage[i]
            }

            if i < inlineWordCount {
                result.inlineStorage[i] = selfWord & otherWord
            }
        }

        return result
    }

    /// Returns a new set with elements in self but not in other.
    ///
    /// - Parameter other: The set to subtract.
    /// - Returns: A new set with elements not in other.
    @inlinable
    public func subtract(_ other: Set<Bit>.Packed.Small<inlineWordCount>) -> Set<Bit>.Packed.Small<inlineWordCount> {
        var result = Set<Bit>.Packed.Small<inlineWordCount>()

        if storedCapacity > Set<Bit>.Packed.Small<inlineWordCount>.inlineCapacity {
            result.spillToHeap(toInclude: storedCapacity - 1)
        }

        let selfWordCount = wordCount
        let otherWordCount = other.wordCount

        for i in 0..<selfWordCount {
            let selfWord = word(at: i)
            let otherWord: UInt
            if i < otherWordCount {
                if let heapStorage = other.heapStorage {
                    otherWord = heapStorage[i]
                } else {
                    otherWord = other.inlineStorage[i]
                }
            } else {
                otherWord = 0
            }

            if result.heapStorage != nil {
                result.heapStorage![i] = selfWord & ~otherWord
            } else if i < inlineWordCount {
                result.inlineStorage[i] = selfWord & ~otherWord
            }
        }

        return result
    }

    /// Nested accessor for symmetric operations.
    @inlinable
    public var symmetric: Symmetric {
        Symmetric(
            inlineStorage: inlineStorage,
            heapStorage: heapStorage,
            storedCapacity: storedCapacity
        )
    }
}

// MARK: - Mutating Algebra Operations

extension Set<Bit>.Packed.Small {
    /// Applies an algebra operation and replaces self with the result.
    ///
    /// - Parameter operation: A closure that takes the algebra accessor and returns a new set.
    @inlinable
    public mutating func form(_ operation: (Algebra) -> Set<Bit>.Packed.Small<inlineWordCount>) {
        self = operation(algebra)
    }
}
