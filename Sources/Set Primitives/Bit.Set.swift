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

// MARK: - Bit.Set

extension Bit {
    /// Packed bit set using word-sized storage.
    ///
    /// `Bit.Set` stores integer indices as individual bits, providing O(1)
    /// membership testing and efficient set algebra operations. Space usage
    /// is proportional to the maximum index stored, not the number of elements.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var set = Bit.Set(capacity: 100)
    /// try set.insert(42)
    /// set.contains(42)        // true
    /// set.count               // 1
    /// try set.remove(42)
    /// set.contains(42)        // false
    /// ```
    ///
    /// ## Variants
    ///
    /// - ``Bit/Set``: Dynamically-growing storage (this type)
    /// - ``Bit/Set/Bounded``: Fixed-capacity, throws on overflow
    /// - ``Bit/Set/Inline``: Zero-allocation inline storage with compile-time capacity
    public struct Set: Sendable {
        @usableFromInline
        static var _bitsPerWord: Int { UInt.bitWidth }

        @usableFromInline
        var _storage: ContiguousArray<UInt>

        @usableFromInline
        var _capacity: Int

        @inlinable
        public init() {
            self._storage = []
            self._capacity = 0
        }

        @inlinable
        public init(capacity: Int) throws(__BitSetError) {
            guard capacity >= 0 else {
                throw .invalidCapacity
            }
            let wordCount = (capacity + Self._bitsPerWord - 1) / Self._bitsPerWord
            self._storage = ContiguousArray(repeating: 0, count: wordCount)
            self._capacity = capacity
        }
    }
}

// MARK: - Properties

extension Bit.Set {
    @inlinable
    public var capacity: Int { _capacity }

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

    @usableFromInline
    var _wordCount: Int { _storage.count }
}

// MARK: - Membership

extension Bit.Set {
    @inlinable
    public func contains(_ index: Int) -> Bool {
        guard index >= 0 && index < _capacity else { return false }
        let wordIndex = index / Self._bitsPerWord
        let bitIndex = index % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        return (_storage[wordIndex] & mask) != 0
    }
}

// MARK: - Mutation

extension Bit.Set {
    @inlinable
    @discardableResult
    public mutating func insert(_ index: Int) throws(__BitSetError) -> Bool {
        guard index >= 0 else {
            throw .bounds(index: index, capacity: _capacity)
        }

        if index >= _capacity {
            try _grow(toInclude: index)
        }

        let wordIndex = index / Self._bitsPerWord
        let bitIndex = index % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex
        let wasSet = (_storage[wordIndex] & mask) != 0
        _storage[wordIndex] |= mask
        return !wasSet
    }

    @inlinable
    @discardableResult
    public mutating func remove(_ index: Int) throws(__BitSetError) -> Bool {
        guard index >= 0 && index < _capacity else {
            throw .bounds(index: index, capacity: _capacity)
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

    @usableFromInline
    mutating func _grow(toInclude index: Int) throws(__BitSetError) {
        let newCapacity = index + 1
        let newWordCount = (newCapacity + Self._bitsPerWord - 1) / Self._bitsPerWord
        let oldWordCount = _storage.count

        if newWordCount > oldWordCount {
            _storage.reserveCapacity(newWordCount)
            for _ in oldWordCount..<newWordCount {
                _storage.append(0)
            }
        }
        _capacity = newCapacity
    }
}

// MARK: - Set Algebra

extension Bit.Set {
    @inlinable
    public func union(_ other: Self) -> Self {
        var result = self
        result.formUnion(other)
        return result
    }

    @inlinable
    public mutating func formUnion(_ other: Self) {
        if other._capacity > _capacity {
            try! _grow(toInclude: other._capacity - 1)
        }
        let minWords = Swift.min(_storage.count, other._storage.count)
        for i in 0..<minWords {
            _storage[i] |= other._storage[i]
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
        let minWords = Swift.min(_storage.count, other._storage.count)
        for i in 0..<minWords {
            _storage[i] &= other._storage[i]
        }
        for i in minWords..<_storage.count {
            _storage[i] = 0
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
        let minWords = Swift.min(_storage.count, other._storage.count)
        for i in 0..<minWords {
            _storage[i] &= ~other._storage[i]
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
        if other._capacity > _capacity {
            try! _grow(toInclude: other._capacity - 1)
        }
        let minWords = Swift.min(_storage.count, other._storage.count)
        for i in 0..<minWords {
            _storage[i] ^= other._storage[i]
        }
    }
}

// MARK: - Set Relations

extension Bit.Set {
    @inlinable
    public func isSubset(of other: Self) -> Bool {
        for i in 0..<_storage.count {
            let selfWord = _storage[i]
            let otherWord = i < other._storage.count ? other._storage[i] : 0
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
        let minWords = Swift.min(_storage.count, other._storage.count)
        for i in 0..<minWords {
            if (_storage[i] & other._storage[i]) != 0 {
                return false
            }
        }
        return true
    }
}

// MARK: - Iteration

extension Bit.Set {
    @inlinable
    public func forEach(_ body: (Int) -> Void) {
        for (wordIndex, var word) in _storage.enumerated() {
            while word != 0 {
                let bitIndex = word.trailingZeroBitCount
                let globalIndex = wordIndex * Self._bitsPerWord + bitIndex
                if globalIndex < _capacity {
                    body(globalIndex)
                }
                word &= word - 1
            }
        }
    }
}

// MARK: - Additional Properties

extension Bit.Set {
    /// The smallest element in the set, or `nil` if empty.
    ///
    /// - Complexity: O(n/w) where w is word bit width
    @inlinable
    public var min: Int? {
        for wordIndex in _storage.indices {
            let word = _storage[wordIndex]
            if word != 0 {
                let lowestBit = word.trailingZeroBitCount
                let element = wordIndex * Self._bitsPerWord + lowestBit
                return element < _capacity ? element : nil
            }
        }
        return nil
    }

    /// The largest element in the set, or `nil` if empty.
    ///
    /// - Complexity: O(n/w) where w is word bit width
    @inlinable
    public var max: Int? {
        for wordIndex in _storage.indices.reversed() {
            let word = _storage[wordIndex]
            if word != 0 {
                let highestBit = UInt.bitWidth - 1 - word.leadingZeroBitCount
                let element = wordIndex * Self._bitsPerWord + highestBit
                return element < _capacity ? element : nil
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

extension Bit.Set {
    /// Creates a bit set from a sequence of integers.
    ///
    /// - Parameter elements: The elements to include.
    /// - Note: Negative elements are ignored.
    @inlinable
    public init<S: Sequence>(_ elements: S) where S.Element == Int {
        self.init()
        for element in elements where element >= 0 {
            try! insert(element)
        }
    }
}

// MARK: - Sequence

extension Bit.Set: Sequence {
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
        public mutating func next() -> Int? {
            while currentWord == 0 {
                wordIndex += 1
                guard wordIndex < storage.count else { return nil }
                currentWord = storage[wordIndex]
            }

            let bit = currentWord.trailingZeroBitCount
            currentWord &= currentWord &- 1  // Clear lowest set bit
            let element = wordIndex * UInt.bitWidth + bit
            return element < capacity ? element : nil
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(storage: _storage, capacity: _capacity)
    }
}

// MARK: - Equatable

extension Bit.Set: Equatable {}

// MARK: - Hashable

extension Bit.Set: Hashable {}

// MARK: - CustomStringConvertible

extension Bit.Set: CustomStringConvertible {
    public var description: String {
        let elements = Swift.Array(self.prefix(10))
        let suffix = count > 10 ? ", ..." : ""
        return "Bit.Set(\(elements.map(String.init).joined(separator: ", "))\(suffix))"
    }
}
