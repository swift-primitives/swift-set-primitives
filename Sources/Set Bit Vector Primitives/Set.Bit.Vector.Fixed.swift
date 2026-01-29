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

// MARK: - Set<Bit>.Vector.Fixed

extension Set<Bit>.Vector {
    /// Fixed-capacity packed bit set.
    ///
    /// `Set<Bit>.Vector.Fixed` allocates storage upfront and throws on overflow.
    /// Use this variant when capacity is known or in contexts requiring
    /// predictable memory behavior.
    public struct Fixed: Sendable {
        @usableFromInline
        static var bitsPerWord: Int { UInt.bitWidth }

        @usableFromInline
        var storage: ContiguousArray<UInt>

        public let capacity: Int

        @inlinable
        public init(capacity: Int) throws(__SetBitVectorFixedError) {
            guard capacity >= 0 else {
                throw .invalidCapacity(.init())
            }
            let wordCount = (capacity + Self.bitsPerWord - 1) / Self.bitsPerWord
            self.storage = ContiguousArray(repeating: 0, count: wordCount)
            self.capacity = capacity
        }

        /// Internal initializer for constructing from storage.
        @usableFromInline
        init(__storage: ContiguousArray<UInt>, capacity: Int) {
            self.storage = __storage
            self.capacity = capacity
        }
    }
}

// MARK: - Properties

extension Set<Bit>.Vector.Fixed {
    @inlinable
    public var count: Int {
        var total = 0
        for word in storage {
            total += word.nonzeroBitCount
        }
        return total
    }

    @inlinable
    public var isEmpty: Bool {
        for word in storage {
            if word != 0 { return false }
        }
        return true
    }
}

// MARK: - Membership

extension Set<Bit>.Vector.Fixed {
    /// Returns whether the set contains the given bit index.
    @inlinable
    public func contains(_ index: Bit.Index) -> Bool {
        contains(Int(bitPattern: index.position))
    }

    /// Returns whether the set contains the given integer index.
    @inlinable
    public func contains(_ index: Int) -> Bool {
        guard index >= 0 && index < capacity else { return false }
        let wordIndex = index / Self.bitsPerWord
        let bitIndex = index % Self.bitsPerWord
        let mask: UInt = 1 << bitIndex
        return (storage[wordIndex] & mask) != 0
    }
}

// MARK: - Mutation

extension Set<Bit>.Vector.Fixed {
    /// Inserts a bit index into the set.
    @inlinable
    @discardableResult
    public mutating func insert(_ index: Bit.Index) throws(__SetBitVectorFixedError) -> Bool {
        try insert(Int(bitPattern: index.position))
    }

    /// Inserts an integer index into the set.
    @inlinable
    @discardableResult
    public mutating func insert(_ index: Int) throws(__SetBitVectorFixedError) -> Bool {
        guard index >= 0 && index < capacity else {
            if index >= capacity {
                throw .overflow(.init())
            }
            throw .bounds(.init(index: index, capacity: capacity))
        }
        let wordIndex = index / Self.bitsPerWord
        let bitIndex = index % Self.bitsPerWord
        let mask: UInt = 1 << bitIndex
        let wasSet = (storage[wordIndex] & mask) != 0
        storage[wordIndex] |= mask
        return !wasSet
    }

    /// Removes a bit index from the set.
    @inlinable
    @discardableResult
    public mutating func remove(_ index: Bit.Index) throws(__SetBitVectorFixedError) -> Bool {
        try remove(Int(bitPattern: index.position))
    }

    /// Removes an integer index from the set.
    @inlinable
    @discardableResult
    public mutating func remove(_ index: Int) throws(__SetBitVectorFixedError) -> Bool {
        guard index >= 0 && index < capacity else {
            throw .bounds(.init(index: index, capacity: capacity))
        }
        let wordIndex = index / Self.bitsPerWord
        let bitIndex = index % Self.bitsPerWord
        let mask: UInt = 1 << bitIndex
        let wasSet = (storage[wordIndex] & mask) != 0
        storage[wordIndex] &= ~mask
        return wasSet
    }

    @inlinable
    public mutating func removeAll() {
        for i in 0..<storage.count {
            storage[i] = 0
        }
    }
}


// MARK: - Iteration

extension Set<Bit>.Vector.Fixed {
    @inlinable
    public func forEach(_ body: (Int) -> Void) {
        for (wordIndex, var word) in storage.enumerated() {
            while word != 0 {
                let bitIndex = word.trailingZeroBitCount
                let globalIndex = wordIndex * Self.bitsPerWord + bitIndex
                if globalIndex < capacity {
                    body(globalIndex)
                }
                word &= word - 1
            }
        }
    }
}

// MARK: - Equatable

extension Set<Bit>.Vector.Fixed: Equatable {
    /// Explicit implementation to avoid compiler crash in synthesized __derived_struct_equals.
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.capacity == rhs.capacity && lhs.storage == rhs.storage
    }
}

// MARK: - Hashable

extension Set<Bit>.Vector.Fixed: Hashable {
    /// Explicit implementation to match explicit Equatable.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(capacity)
        hasher.combine(storage)
    }
}
