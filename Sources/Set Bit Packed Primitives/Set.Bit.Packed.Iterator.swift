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
import Ordinal_Primitives

// MARK: - Sequence

extension Set<Bit>.Packed: Swift.Sequence {
    /// An iterator over the elements of a bit set.
    ///
    /// Elements are yielded in ascending order.
    public struct Iterator: IteratorProtocol, Sendable {
        @usableFromInline
        let storage: ContiguousArray<UInt>

        @usableFromInline
        let capacity: Int

        @usableFromInline
        var wordIndex: Int

        @usableFromInline
        var currentWord: UInt

        @usableFromInline
        init(storage: ContiguousArray<UInt>, capacity: Int) {
            self.storage = storage
            self.capacity = capacity
            self.wordIndex = 0
            self.currentWord = storage.isEmpty ? 0 : storage[0]
        }

        @inlinable
        public mutating func next() -> Bit.Index? {
            while currentWord == 0 {
                wordIndex += 1
                guard wordIndex < storage.count else { return nil }
                currentWord = storage[wordIndex]
            }

            let bit = currentWord.trailingZeroBitCount
            currentWord &= currentWord &- 1  // Clear lowest set bit
            let element = wordIndex * UInt.bitWidth + bit
            return element < capacity ? Bit.Index(__unchecked: (), Ordinal(UInt(element))) : nil
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(storage: storage, capacity: capacity)
    }
}


// MARK: - Iteration

extension Set<Bit>.Packed {
    @inlinable
    public func forEach(_ body: (Bit.Index) -> Void) {
        for (wordIndex, var word) in storage.enumerated() {
            while word != 0 {
                let bitIndex = word.trailingZeroBitCount
                let globalIndex = wordIndex * Self.bitsPerWord + bitIndex
                if globalIndex < capacity {
                    body(Bit.Index(__unchecked: (), Ordinal(UInt(globalIndex))))
                }
                word &= word - 1
            }
        }
    }
}
