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

// MARK: - Set<Bit>.Packed.Inline

extension Set<Bit>.Packed {
    /// Fixed-capacity packed bit set with inline storage.
    ///
    /// `Set<Bit>.Packed.Inline` uses zero-allocation inline storage with compile-time
    /// capacity. Ideal for small bit sets where heap allocation is unnecessary.
    public struct Inline<let wordCount: Int>: Sendable {
        @usableFromInline
        static var bitsPerWord: Int { UInt.bitWidth }

        @inlinable
        public static var capacity: Int { wordCount * bitsPerWord }

        @usableFromInline
        var storage: InlineArray<wordCount, UInt>

        @inlinable
        public init() {
            self.storage = InlineArray(repeating: 0)
        }
    }
}

// MARK: - Properties

extension Set<Bit>.Packed.Inline {
    @inlinable
    public var capacity: Int { Self.capacity }

    @inlinable
    public var count: Int {
        var total = 0
        for i in 0..<wordCount {
            total += storage[i].nonzeroBitCount
        }
        return total
    }

    @inlinable
    public var isEmpty: Bool {
        for i in 0..<wordCount {
            if storage[i] != 0 { return false }
        }
        return true
    }
}

// MARK: - Membership

extension Set<Bit>.Packed.Inline {
    /// Returns whether the set contains the given bit index.
    @inlinable
    public func contains(_ index: Bit.Index) -> Bool {
        contains(index.position.rawValue)
    }

    /// Returns whether the set contains the given integer index.
    @inlinable
    public func contains(_ index: Int) -> Bool {
        guard index >= 0 && index < Self.capacity else { return false }
        let wordIndex = index / Self.bitsPerWord
        let bitIndex = index % Self.bitsPerWord
        let mask: UInt = 1 << bitIndex
        return (storage[wordIndex] & mask) != 0
    }
}

// MARK: - Mutation

extension Set<Bit>.Packed.Inline {
    /// Inserts a bit index into the set.
    @inlinable
    @discardableResult
    public mutating func insert(_ index: Bit.Index) throws(__SetBitPackedInlineError) -> Bool {
        try insert(index.position.rawValue)
    }

    /// Inserts an integer index into the set.
    @inlinable
    @discardableResult
    public mutating func insert(_ index: Int) throws(__SetBitPackedInlineError) -> Bool {
        guard index >= 0 && index < Self.capacity else {
            if index >= Self.capacity {
                throw .overflow(.init())
            }
            throw .bounds(.init(index: index, capacity: Self.capacity))
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
    public mutating func remove(_ index: Bit.Index) throws(__SetBitPackedInlineError) -> Bool {
        try remove(index.position.rawValue)
    }

    /// Removes an integer index from the set.
    @inlinable
    @discardableResult
    public mutating func remove(_ index: Int) throws(__SetBitPackedInlineError) -> Bool {
        guard index >= 0 && index < Self.capacity else {
            throw .bounds(.init(index: index, capacity: Self.capacity))
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
        for i in 0..<wordCount {
            storage[i] = 0
        }
    }
}

// MARK: - Set Algebra

extension Set<Bit>.Packed.Inline {
    @inlinable
    public func union(_ other: Self) -> Self {
        var result = self
        result.formUnion(other)
        return result
    }

    @inlinable
    public mutating func formUnion(_ other: Self) {
        for i in 0..<wordCount {
            storage[i] |= other.storage[i]
        }
    }

    @inlinable
    public func intersection(_ other: Self) -> Self {
        var result = self
        result.formIntersection(other)
        return result
    }

    @inlinable
    public mutating func formIntersection(_ other: Self) {
        for i in 0..<wordCount {
            storage[i] &= other.storage[i]
        }
    }

    @inlinable
    public func subtracting(_ other: Self) -> Self {
        var result = self
        result.subtract(other)
        return result
    }

    @inlinable
    public mutating func subtract(_ other: Self) {
        for i in 0..<wordCount {
            storage[i] &= ~other.storage[i]
        }
    }

    @inlinable
    public func symmetricDifference(_ other: Self) -> Self {
        var result = self
        result.formSymmetricDifference(other)
        return result
    }

    @inlinable
    public mutating func formSymmetricDifference(_ other: Self) {
        for i in 0..<wordCount {
            storage[i] ^= other.storage[i]
        }
    }
}

// MARK: - Set Relations

extension Set<Bit>.Packed.Inline {
    @inlinable
    public func isSubset(of other: Self) -> Bool {
        for i in 0..<wordCount {
            if (storage[i] & ~other.storage[i]) != 0 {
                return false
            }
        }
        return true
    }

    @inlinable
    public func isSuperset(of other: Self) -> Bool {
        other.isSubset(of: self)
    }

    @inlinable
    public func isDisjoint(with other: Self) -> Bool {
        for i in 0..<wordCount {
            if (storage[i] & other.storage[i]) != 0 {
                return false
            }
        }
        return true
    }
}

// MARK: - Iteration

extension Set<Bit>.Packed.Inline {
    @inlinable
    public func forEach(_ body: (Int) -> Void) {
        for wordIndex in 0..<wordCount {
            var word = storage[wordIndex]
            while word != 0 {
                let bitIndex = word.trailingZeroBitCount
                let globalIndex = wordIndex * Self.bitsPerWord + bitIndex
                body(globalIndex)
                word &= word - 1
            }
        }
    }
}

// MARK: - Equatable

extension Set<Bit>.Packed.Inline: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        for i in 0..<wordCount {
            if lhs.storage[i] != rhs.storage[i] { return false }
        }
        return true
    }
}

// MARK: - Hashable

extension Set<Bit>.Packed.Inline: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        for i in 0..<wordCount {
            hasher.combine(storage[i])
        }
    }
}
