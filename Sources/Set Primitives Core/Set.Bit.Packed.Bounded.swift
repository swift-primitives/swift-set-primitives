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

// MARK: - Set<Bit>.Packed.Bounded

extension Set<Bit>.Packed {
    /// Fixed-capacity packed bit set.
    ///
    /// `Set<Bit>.Packed.Bounded` allocates storage upfront and throws on overflow.
    /// Use this variant when capacity is known or in contexts requiring
    /// predictable memory behavior.
    public struct Bounded: Sendable {
        @usableFromInline
        static var _bitsPerWord: Int { UInt.bitWidth }

        @usableFromInline
        var _storage: ContiguousArray<UInt>

        public let capacity: Int

        @inlinable
        public init(capacity: Int) throws(__SetBitPackedBoundedError) {
            guard capacity >= 0 else {
                throw .invalidCapacity(.init())
            }
            let wordCount = (capacity + Self._bitsPerWord - 1) / Self._bitsPerWord
            self._storage = ContiguousArray(repeating: 0, count: wordCount)
            self.capacity = capacity
        }
    }
}

// MARK: - Properties

extension Set<Bit>.Packed.Bounded {
    @inlinable
    public var count: Int {
        var total = 0
        for word in _storage {
            total += word.nonzeroBitCount
        }
        return total
    }

    @inlinable
    public var isEmpty: Bool {
        for word in _storage {
            if word != 0 { return false }
        }
        return true
    }
}

// MARK: - Membership

extension Set<Bit>.Packed.Bounded {
    /// Returns whether the set contains the given bit index.
    @inlinable
    public func contains(_ index: Bit.Index) -> Bool {
        contains(index.position.rawValue)
    }

    /// Returns whether the set contains the given integer index.
    @inlinable
    public func contains(_ index: Int) -> Bool {
        guard index >= 0 && index < capacity else { return false }
        let wordIndex = index / Self._bitsPerWord
        let bitIndex = index % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        return (_storage[wordIndex] & mask) != 0
    }
}

// MARK: - Mutation

extension Set<Bit>.Packed.Bounded {
    /// Inserts a bit index into the set.
    @inlinable
    @discardableResult
    public mutating func insert(_ index: Bit.Index) throws(__SetBitPackedBoundedError) -> Bool {
        try insert(index.position.rawValue)
    }

    /// Inserts an integer index into the set.
    @inlinable
    @discardableResult
    public mutating func insert(_ index: Int) throws(__SetBitPackedBoundedError) -> Bool {
        guard index >= 0 && index < capacity else {
            if index >= capacity {
                throw .overflow(.init())
            }
            throw .bounds(.init(index: index, capacity: capacity))
        }
        let wordIndex = index / Self._bitsPerWord
        let bitIndex = index % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        let wasSet = (_storage[wordIndex] & mask) != 0
        _storage[wordIndex] |= mask
        return !wasSet
    }

    /// Removes a bit index from the set.
    @inlinable
    @discardableResult
    public mutating func remove(_ index: Bit.Index) throws(__SetBitPackedBoundedError) -> Bool {
        try remove(index.position.rawValue)
    }

    /// Removes an integer index from the set.
    @inlinable
    @discardableResult
    public mutating func remove(_ index: Int) throws(__SetBitPackedBoundedError) -> Bool {
        guard index >= 0 && index < capacity else {
            throw .bounds(.init(index: index, capacity: capacity))
        }
        let wordIndex = index / Self._bitsPerWord
        let bitIndex = index % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        let wasSet = (_storage[wordIndex] & mask) != 0
        _storage[wordIndex] &= ~mask
        return wasSet
    }

    @inlinable
    public mutating func removeAll() {
        for i in 0..<_storage.count {
            _storage[i] = 0
        }
    }
}

// MARK: - Set Algebra

extension Set<Bit>.Packed.Bounded {
    @inlinable
    public func union(_ other: Self) -> Self {
        precondition(capacity == other.capacity, "Capacities must match")
        var result = self
        result.formUnion(other)
        return result
    }

    @inlinable
    public mutating func formUnion(_ other: Self) {
        precondition(capacity == other.capacity, "Capacities must match")
        for i in 0..<_storage.count {
            _storage[i] |= other._storage[i]
        }
    }

    @inlinable
    public func intersection(_ other: Self) -> Self {
        precondition(capacity == other.capacity, "Capacities must match")
        var result = self
        result.formIntersection(other)
        return result
    }

    @inlinable
    public mutating func formIntersection(_ other: Self) {
        precondition(capacity == other.capacity, "Capacities must match")
        for i in 0..<_storage.count {
            _storage[i] &= other._storage[i]
        }
    }

    @inlinable
    public func subtracting(_ other: Self) -> Self {
        precondition(capacity == other.capacity, "Capacities must match")
        var result = self
        result.subtract(other)
        return result
    }

    @inlinable
    public mutating func subtract(_ other: Self) {
        precondition(capacity == other.capacity, "Capacities must match")
        for i in 0..<_storage.count {
            _storage[i] &= ~other._storage[i]
        }
    }

    @inlinable
    public func symmetricDifference(_ other: Self) -> Self {
        precondition(capacity == other.capacity, "Capacities must match")
        var result = self
        result.formSymmetricDifference(other)
        return result
    }

    @inlinable
    public mutating func formSymmetricDifference(_ other: Self) {
        precondition(capacity == other.capacity, "Capacities must match")
        for i in 0..<_storage.count {
            _storage[i] ^= other._storage[i]
        }
    }
}

// MARK: - Set Relations

extension Set<Bit>.Packed.Bounded {
    @inlinable
    public func isSubset(of other: Self) -> Bool {
        precondition(capacity == other.capacity, "Capacities must match")
        for i in 0..<_storage.count {
            if (_storage[i] & ~other._storage[i]) != 0 {
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
        precondition(capacity == other.capacity, "Capacities must match")
        for i in 0..<_storage.count {
            if (_storage[i] & other._storage[i]) != 0 {
                return false
            }
        }
        return true
    }
}

// MARK: - Iteration

extension Set<Bit>.Packed.Bounded {
    @inlinable
    public func forEach(_ body: (Int) -> Void) {
        for (wordIndex, var word) in _storage.enumerated() {
            while word != 0 {
                let bitIndex = word.trailingZeroBitCount
                let globalIndex = wordIndex * Self._bitsPerWord + bitIndex
                if globalIndex < capacity {
                    body(globalIndex)
                }
                word &= word - 1
            }
        }
    }
}

// MARK: - Equatable

extension Set<Bit>.Packed.Bounded: Equatable {
    /// Explicit implementation to avoid compiler crash in synthesized __derived_struct_equals.
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.capacity == rhs.capacity && lhs._storage == rhs._storage
    }
}

// MARK: - Hashable

extension Set<Bit>.Packed.Bounded: Hashable {
    /// Explicit implementation to match explicit Equatable.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(capacity)
        hasher.combine(_storage)
    }
}
