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

extension Set<Bit>.Packed.Algebra {
    /// Namespace for symmetric set operations.
    public struct Symmetric: Sendable {
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

// MARK: - Symmetric Operations

extension Set<Bit>.Packed.Algebra.Symmetric {
    /// Returns a new set with elements in either set, but not both.
    ///
    /// - Parameter other: The other set.
    /// - Returns: A new set with elements in exactly one of the sets.
    /// - Complexity: O(n) where n is the number of words.
    @inlinable
    public func difference(_ other: Set<Bit>.Packed) -> Set<Bit>.Packed {
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
            resultStorage[i] ^= other.storage[i]
        }

        return Set<Bit>.Packed(__storage: resultStorage, capacity: resultCapacity)
    }
}
