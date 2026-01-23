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

// MARK: - Set<Bit>.Packed

extension Set where Element == Bit {
    /// Packed bit set using word-sized storage.
    ///
    /// `Set<Bit>.Packed` stores `Bit.Index` values as individual bits, providing O(1)
    /// membership testing and efficient set algebra operations. Space usage
    /// is proportional to the maximum index stored, not the number of elements.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var set = Set<Bit>.Packed(capacity: 100)
    /// try set.insert(Bit.Index(__unchecked: 42))
    /// set.contains(Bit.Index(__unchecked: 42))  // true
    /// set.count                                  // 1
    /// try set.remove(Bit.Index(__unchecked: 42))
    /// set.contains(Bit.Index(__unchecked: 42))  // false
    /// ```
    ///
    /// ## Variants
    ///
    /// - ``Set/Packed-swift.struct``: Dynamically-growing storage (this type)
    /// - ``Set/Packed-swift.struct/Bounded``: Fixed-capacity, throws on overflow
    /// - ``Set/Packed-swift.struct/Inline``: Zero-allocation inline storage with compile-time capacity
    /// - ``Set/Packed-swift.struct/Small``: Inline storage with automatic spill to heap
    public struct Packed: Sendable {
        @usableFromInline
        static var bitsPerWord: Int { UInt.bitWidth }

        @usableFromInline
        var storage: ContiguousArray<UInt>

        @usableFromInline
        var storedCapacity: Int

        @inlinable
        public init() {
            self.storage = []
            self.storedCapacity = 0
        }

        @inlinable
        public init(capacity: Int) throws(__SetBitPackedError) {
            guard capacity >= 0 else {
                throw .invalidCapacity(.init())
            }
            let wordCount = (capacity + Self.bitsPerWord - 1) / Self.bitsPerWord
            self.storage = ContiguousArray(repeating: 0, count: wordCount)
            self.storedCapacity = capacity
        }
    }
}

// MARK: - Properties

extension Set<Bit>.Packed {
    @inlinable
    public var capacity: Int { storedCapacity }

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

    @usableFromInline
    var wordCount: Int { storage.count }
}

// MARK: - Membership

extension Set<Bit>.Packed {
    @inlinable
    public func contains(_ index: Bit.Index) -> Bool {
        let i = index.position.rawValue
        guard i >= 0 && i < capacity else { return false }
        let wordIndex = i / Self.bitsPerWord
        let bitIndex = i % Self.bitsPerWord
        let mask: UInt = 1 << bitIndex
        return (storage[wordIndex] & mask) != 0
    }
}

// MARK: - Mutation

extension Set<Bit>.Packed {
    @inlinable
    @discardableResult
    public mutating func insert(_ index: Bit.Index) throws(__SetBitPackedError) -> Bool {
        let i = index.position.rawValue
        guard i >= 0 else {
            throw .bounds(.init(index: i, capacity: capacity))
        }

        if i >= capacity {
            grow(toInclude: i)
        }

        let wordIndex = i / Self.bitsPerWord
        let bitIndex = i % Self.bitsPerWord
        let mask: UInt = 1 << bitIndex
        let wasSet = (storage[wordIndex] & mask) != 0
        storage[wordIndex] |= mask
        return !wasSet
    }

    @inlinable
    @discardableResult
    public mutating func remove(_ index: Bit.Index) throws(__SetBitPackedError) -> Bool {
        let i = index.position.rawValue
        guard i >= 0 && i < capacity else {
            throw .bounds(.init(index: i, capacity: capacity))
        }
        let wordIndex = i / Self.bitsPerWord
        let bitIndex = i % Self.bitsPerWord
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

    @usableFromInline
    mutating func grow(toInclude index: Int) {
        let newCapacity = index + 1
        let newWordCount = (newCapacity + Self.bitsPerWord - 1) / Self.bitsPerWord
        let oldWordCount = storage.count

        if newWordCount > oldWordCount {
            storage.reserveCapacity(newWordCount)
            for _ in oldWordCount..<newWordCount {
                storage.append(0)
            }
        }
        storedCapacity = newCapacity
    }
}

// MARK: - Set Algebra

extension Set<Bit>.Packed {
    @inlinable
    public func union(_ other: Self) -> Self {
        var result = self
        result.formUnion(other)
        return result
    }

    @inlinable
    public mutating func formUnion(_ other: Self) {
        if other.capacity > capacity {
            grow(toInclude: other.capacity - 1)
        }
        let minWords = Swift.min(storage.count, other.storage.count)
        for i in 0..<minWords {
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
        let minWords = Swift.min(storage.count, other.storage.count)
        for i in 0..<minWords {
            storage[i] &= other.storage[i]
        }
        for i in minWords..<storage.count {
            storage[i] = 0
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
        let minWords = Swift.min(storage.count, other.storage.count)
        for i in 0..<minWords {
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
        if other.capacity > capacity {
            grow(toInclude: other.capacity - 1)
        }
        let minWords = Swift.min(storage.count, other.storage.count)
        for i in 0..<minWords {
            storage[i] ^= other.storage[i]
        }
    }
}

// MARK: - Set Relations

extension Set<Bit>.Packed {
    @inlinable
    public func isSubset(of other: Self) -> Bool {
        for i in 0..<storage.count {
            let selfWord = storage[i]
            let otherWord = i < other.storage.count ? other.storage[i] : 0
            if (selfWord & ~otherWord) != 0 {
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
        let minWords = Swift.min(storage.count, other.storage.count)
        for i in 0..<minWords {
            if (storage[i] & other.storage[i]) != 0 {
                return false
            }
        }
        return true
    }
}

// MARK: - Additional Properties

extension Set<Bit>.Packed {
    /// The smallest element in the set, or `nil` if empty.
    ///
    /// - Complexity: O(n/w) where w is word bit width
    @inlinable
    public var min: Bit.Index? {
        for wordIndex in storage.indices {
            let word = storage[wordIndex]
            if word != 0 {
                let lowestBit = word.trailingZeroBitCount
                let element = wordIndex * Self.bitsPerWord + lowestBit
                return element < capacity ? Bit.Index(__unchecked: (), position: element) : nil
            }
        }
        return nil
    }

    /// The largest element in the set, or `nil` if empty.
    ///
    /// - Complexity: O(n/w) where w is word bit width
    @inlinable
    public var max: Bit.Index? {
        for wordIndex in storage.indices.reversed() {
            let word = storage[wordIndex]
            if word != 0 {
                let highestBit = UInt.bitWidth - 1 - word.leadingZeroBitCount
                let element = wordIndex * Self.bitsPerWord + highestBit
                return element < capacity ? Bit.Index(__unchecked: (), position: element) : nil
            }
        }
        return nil
    }

    /// Removes all elements from the set.
    ///
    /// This is an alias for ``removeAll()``.
    @inlinable
    public mutating func clear() {
        removeAll()
    }
}

// MARK: - Additional Initializers

extension Set<Bit>.Packed {
    /// Creates a bit set from a sequence of bit indices.
    ///
    /// - Parameter elements: The elements to include.
    @inlinable
    public init<S: Swift.Sequence>(_ elements: S) where S.Element == Bit.Index {
        self.init()
        for element in elements {
            try! insert(element)
        }
    }
}

// MARK: - Equatable

extension Set<Bit>.Packed: Equatable {}

// MARK: - Hashable

extension Set<Bit>.Packed: Hashable {}

// MARK: - CustomStringConvertible

extension Set<Bit>.Packed: CustomStringConvertible {
    public var description: String {
        let elements = Swift.Array(self.prefix(10))
        let suffix = count > 10 ? ", ..." : ""
        return "Set<Bit>.Packed(\(elements.map { String($0.position.rawValue) }.joined(separator: ", "))\(suffix))"
    }
}
