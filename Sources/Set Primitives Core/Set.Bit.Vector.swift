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

// MARK: - Set<Bit>.Vector

extension Set where Element == Bit {
    /// Packed bit set using word-sized storage.
    ///
    /// `Set<Bit>.Vector` stores `Bit.Index` values as individual bits, providing O(1)
    /// membership testing and efficient set algebra operations. Space usage
    /// is proportional to the maximum index stored, not the number of elements.
    ///
    /// ## Variants
    ///
    /// - ``Set/Vector-swift.struct``: Dynamically-growing storage (this type)
    /// - ``Set/Vector-swift.struct/Fixed``: Fixed-capacity, throws on overflow
    /// - ``Set/Vector-swift.struct/Inline``: Zero-allocation inline storage with compile-time capacity
    /// - ``Set/Vector-swift.struct/Small``: Inline storage with automatic spill to heap
    public struct Vector: Sendable {
        @inlinable
        public static var bitsPerWord: Int { UInt.bitWidth }

        public var storage: ContiguousArray<UInt>

        public var storedCapacity: Int

        @inlinable
        public init() {
            self.storage = []
            self.storedCapacity = 0
        }

        @inlinable
        public init(capacity: Int) throws(__SetBitVectorError) {
            guard capacity >= 0 else {
                throw .invalidCapacity(.init())
            }
            let wordCount = (capacity + Self.bitsPerWord - 1) / Self.bitsPerWord
            self.storage = ContiguousArray(repeating: 0, count: wordCount)
            self.storedCapacity = capacity
        }

        /// Internal initializer for constructing from storage.
        @inlinable
        public init(__storage: ContiguousArray<UInt>, capacity: Int) {
            self.storage = __storage
            self.storedCapacity = capacity
        }
    }
}
