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

extension Set<Bit>.Packed.Small.Algebra {
    /// Namespace for symmetric set operations.
    public struct Symmetric: Sendable {
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

// MARK: - Symmetric Operations

extension Set<Bit>.Packed.Small.Algebra.Symmetric {
    /// Returns a new set with elements in either set, but not both.
    ///
    /// - Parameter other: The other set.
    /// - Returns: A new set with elements in exactly one of the sets.
    @inlinable
    public func difference(_ other: Set<Bit>.Packed.Small<inlineWordCount>) -> Set<Bit>.Packed.Small<inlineWordCount> {
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
                result.heapStorage![i] = selfWord ^ otherWord
            } else {
                result.inlineStorage[i] = selfWord ^ otherWord
            }
        }

        return result
    }
}
