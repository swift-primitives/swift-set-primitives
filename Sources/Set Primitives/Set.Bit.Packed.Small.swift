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

// MARK: - Set<Bit>.Packed.Small

extension Set<Bit>.Packed {
    /// Packed bit set with small-buffer optimization.
    ///
    /// Uses inline storage until capacity is exceeded, then spills to heap.
    /// Ideal when most sets fit in inline storage but some may need to grow.
    ///
    /// ## Storage Modes
    ///
    /// - **Inline mode**: Uses `InlineArray<inlineWordCount, UInt>` for zero-allocation storage
    /// - **Heap mode**: Uses `ContiguousArray<UInt>` for unlimited growth
    ///
    /// ## Example
    ///
    /// ```swift
    /// // 2 words = 128 bits inline capacity
    /// var set = Set<Bit>.Packed.Small<2>()
    ///
    /// // These fit in inline storage
    /// try set.insert(Bit.Index(__unchecked: 0))
    /// try set.insert(Bit.Index(__unchecked: 127))
    /// set.isSpilled  // false
    ///
    /// // This triggers spill to heap
    /// try set.insert(Bit.Index(__unchecked: 128))
    /// set.isSpilled  // true
    /// ```
    ///
    /// ## Spill Behavior
    ///
    /// - Spill occurs when inserting an index >= `inlineCapacity`
    /// - Once spilled, the set remains heap-allocated
    /// - `clear()` resets to inline mode
    ///
    /// ## Copyable
    ///
    /// Unlike `Stack.Small<Element>` which is `~Copyable` because it stores
    /// potentially move-only elements, `Set<Bit>.Packed.Small` stores only `UInt`
    /// words (always trivial) and has no generic element type. Therefore it is
    /// unconditionally `Copyable`, enabling `Sequence`, `Equatable`, and `Hashable`.
    public struct Small<let inlineWordCount: Int>: Sendable {
        @usableFromInline
        static var _bitsPerWord: Int { UInt.bitWidth }

        /// The number of bits that can be stored inline without heap allocation.
        @inlinable
        public static var inlineCapacity: Int { inlineWordCount * _bitsPerWord }

        @usableFromInline
        var _inlineStorage: InlineArray<inlineWordCount, UInt>

        @usableFromInline
        var _capacity: Int

        @usableFromInline
        var _heapStorage: ContiguousArray<UInt>?

        /// Creates an empty small bit set.
        @inlinable
        public init() {
            self._inlineStorage = InlineArray(repeating: 0)
            self._capacity = Self.inlineCapacity
            self._heapStorage = nil
        }

        /// Whether the set has spilled to heap storage.
        @inlinable
        public var isSpilled: Bool { _heapStorage != nil }
    }
}

// MARK: - Properties

extension Set<Bit>.Packed.Small {
    /// The current capacity of the set.
    @inlinable
    public var capacity: Int { _capacity }

    /// The number of bits set (popcount).
    @inlinable
    public var count: Int {
        if let heapStorage = _heapStorage {
            var total = 0
            for word in heapStorage {
                total += word.nonzeroBitCount
            }
            return total
        } else {
            var total = 0
            for i in 0..<inlineWordCount {
                total += _inlineStorage[i].nonzeroBitCount
            }
            return total
        }
    }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool {
        if let heapStorage = _heapStorage {
            for word in heapStorage {
                if word != 0 { return false }
            }
            return true
        } else {
            for i in 0..<inlineWordCount {
                if _inlineStorage[i] != 0 { return false }
            }
            return true
        }
    }

    @usableFromInline
    var _wordCount: Int {
        if let heapStorage = _heapStorage {
            return heapStorage.count
        } else {
            return inlineWordCount
        }
    }
}

// MARK: - Membership

extension Set<Bit>.Packed.Small {
    /// Returns whether the set contains the given index.
    @inlinable
    public func contains(_ index: Bit.Index) -> Bool {
        let i = index.position.rawValue
        guard i >= 0 && i < _capacity else { return false }
        let wordIndex = i / Self._bitsPerWord
        let bitIndex = i % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex

        if let heapStorage = _heapStorage {
            return (heapStorage[wordIndex] & mask) != 0
        } else {
            return (_inlineStorage[wordIndex] & mask) != 0
        }
    }

    /// Returns whether the set contains the given integer index.
    @inlinable
    public func contains(_ index: Int) -> Bool {
        guard index >= 0 && index < _capacity else { return false }
        let wordIndex = index / Self._bitsPerWord
        let bitIndex = index % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex

        if let heapStorage = _heapStorage {
            return (heapStorage[wordIndex] & mask) != 0
        } else {
            return (_inlineStorage[wordIndex] & mask) != 0
        }
    }
}

// MARK: - Mutation

extension Set<Bit>.Packed.Small {
    /// Inserts a bit index into the set.
    ///
    /// If the index exceeds inline capacity, the set spills to heap storage.
    ///
    /// - Parameter index: The bit index to insert.
    /// - Returns: `true` if the bit was newly inserted, `false` if already present.
    /// - Throws: `__SetBitPackedSmallError.bounds` if the index is negative.
    @inlinable
    @discardableResult
    public mutating func insert(_ index: Bit.Index) throws(__SetBitPackedSmallError) -> Bool {
        let i = index.position.rawValue
        guard i >= 0 else {
            throw .bounds(index: i, capacity: _capacity)
        }

        // Spill to heap if needed
        if i >= _capacity {
            _spillToHeap(toInclude: i)
        }

        let wordIndex = i / Self._bitsPerWord
        let bitIndex = i % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex

        if _heapStorage != nil {
            let wasSet = (_heapStorage![wordIndex] & mask) != 0
            _heapStorage![wordIndex] |= mask
            return !wasSet
        } else {
            let wasSet = (_inlineStorage[wordIndex] & mask) != 0
            _inlineStorage[wordIndex] |= mask
            return !wasSet
        }
    }

    /// Inserts an integer index into the set.
    @inlinable
    @discardableResult
    public mutating func insert(_ index: Int) throws(__SetBitPackedSmallError) -> Bool {
        try insert(Bit.Index(__unchecked: (), position: index))
    }

    /// Removes a bit index from the set.
    ///
    /// - Parameter index: The bit index to remove.
    /// - Returns: `true` if the bit was present and removed, `false` if not present.
    /// - Throws: `__SetBitPackedSmallError.bounds` if the index is out of bounds.
    @inlinable
    @discardableResult
    public mutating func remove(_ index: Bit.Index) throws(__SetBitPackedSmallError) -> Bool {
        let i = index.position.rawValue
        guard i >= 0 && i < _capacity else {
            throw .bounds(index: i, capacity: _capacity)
        }

        let wordIndex = i / Self._bitsPerWord
        let bitIndex = i % Self._bitsPerWord
        let mask: UInt = 1 << bitIndex

        if _heapStorage != nil {
            let wasSet = (_heapStorage![wordIndex] & mask) != 0
            _heapStorage![wordIndex] &= ~mask
            return wasSet
        } else {
            let wasSet = (_inlineStorage[wordIndex] & mask) != 0
            _inlineStorage[wordIndex] &= ~mask
            return wasSet
        }
    }

    /// Removes an integer index from the set.
    @inlinable
    @discardableResult
    public mutating func remove(_ index: Int) throws(__SetBitPackedSmallError) -> Bool {
        try remove(Bit.Index(__unchecked: (), position: index))
    }

    /// Removes all elements from the set.
    @inlinable
    public mutating func removeAll() {
        if _heapStorage != nil {
            for i in 0..<_heapStorage!.count {
                _heapStorage![i] = 0
            }
        } else {
            for i in 0..<inlineWordCount {
                _inlineStorage[i] = 0
            }
        }
    }

    /// Removes all elements and resets to inline storage mode.
    @inlinable
    public mutating func clear() {
        _heapStorage = nil
        _capacity = Self.inlineCapacity
        for i in 0..<inlineWordCount {
            _inlineStorage[i] = 0
        }
    }

    @usableFromInline
    mutating func _spillToHeap(toInclude index: Int) {
        let newCapacity = index + 1
        let newWordCount = (newCapacity + Self._bitsPerWord - 1) / Self._bitsPerWord

        if var existingHeap = _heapStorage {
            // Already spilled - grow the heap storage
            let oldWordCount = existingHeap.count
            if newWordCount > oldWordCount {
                existingHeap.reserveCapacity(newWordCount)
                for _ in oldWordCount..<newWordCount {
                    existingHeap.append(0)
                }
                _heapStorage = existingHeap
            }
            _capacity = newCapacity
        } else {
            // First spill - copy from inline to heap
            var newStorage = ContiguousArray<UInt>()
            newStorage.reserveCapacity(newWordCount)

            // Copy inline storage to heap
            for i in 0..<inlineWordCount {
                newStorage.append(_inlineStorage[i])
            }

            // Add new words
            for _ in inlineWordCount..<newWordCount {
                newStorage.append(0)
            }

            _heapStorage = newStorage
            _capacity = newCapacity
        }
    }
}

// MARK: - Set Algebra

extension Set<Bit>.Packed.Small {
    /// Returns the union of this set with another.
    @inlinable
    public func union(_ other: Self) -> Self {
        var result = Self()

        let maxCapacity = Swift.max(_capacity, other._capacity)
        if maxCapacity > Self.inlineCapacity {
            result._spillToHeap(toInclude: maxCapacity - 1)
        }

        let selfWordCount = _wordCount
        let otherWordCount = other._wordCount
        let resultWordCount = result._wordCount

        for i in 0..<resultWordCount {
            let selfWord: UInt
            if i < selfWordCount {
                if let heapStorage = _heapStorage {
                    selfWord = heapStorage[i]
                } else {
                    selfWord = _inlineStorage[i]
                }
            } else {
                selfWord = 0
            }

            let otherWord: UInt
            if i < otherWordCount {
                if let heapStorage = other._heapStorage {
                    otherWord = heapStorage[i]
                } else {
                    otherWord = other._inlineStorage[i]
                }
            } else {
                otherWord = 0
            }

            if result._heapStorage != nil {
                result._heapStorage![i] = selfWord | otherWord
            } else {
                result._inlineStorage[i] = selfWord | otherWord
            }
        }

        return result
    }

    /// Returns the intersection of this set with another.
    @inlinable
    public func intersection(_ other: Self) -> Self {
        var result = Self()

        let minWordCount = Swift.min(_wordCount, other._wordCount)

        for i in 0..<minWordCount {
            let selfWord: UInt
            if let heapStorage = _heapStorage {
                selfWord = heapStorage[i]
            } else {
                selfWord = _inlineStorage[i]
            }

            let otherWord: UInt
            if let heapStorage = other._heapStorage {
                otherWord = heapStorage[i]
            } else {
                otherWord = other._inlineStorage[i]
            }

            if i < inlineWordCount {
                result._inlineStorage[i] = selfWord & otherWord
            }
        }

        return result
    }

    /// Returns this set with elements from another removed.
    @inlinable
    public func subtracting(_ other: Self) -> Self {
        var result = Self()

        if _capacity > Self.inlineCapacity {
            result._spillToHeap(toInclude: _capacity - 1)
        }

        let selfWordCount = _wordCount
        let otherWordCount = other._wordCount

        for i in 0..<selfWordCount {
            let selfWord: UInt
            if let heapStorage = _heapStorage {
                selfWord = heapStorage[i]
            } else {
                selfWord = _inlineStorage[i]
            }

            let otherWord: UInt
            if i < otherWordCount {
                if let heapStorage = other._heapStorage {
                    otherWord = heapStorage[i]
                } else {
                    otherWord = other._inlineStorage[i]
                }
            } else {
                otherWord = 0
            }

            if result._heapStorage != nil {
                result._heapStorage![i] = selfWord & ~otherWord
            } else if i < inlineWordCount {
                result._inlineStorage[i] = selfWord & ~otherWord
            }
        }

        return result
    }

    /// Returns the symmetric difference of this set with another.
    @inlinable
    public func symmetricDifference(_ other: Self) -> Self {
        var result = Self()

        let maxCapacity = Swift.max(_capacity, other._capacity)
        if maxCapacity > Self.inlineCapacity {
            result._spillToHeap(toInclude: maxCapacity - 1)
        }

        let selfWordCount = _wordCount
        let otherWordCount = other._wordCount
        let resultWordCount = result._wordCount

        for i in 0..<resultWordCount {
            let selfWord: UInt
            if i < selfWordCount {
                if let heapStorage = _heapStorage {
                    selfWord = heapStorage[i]
                } else {
                    selfWord = _inlineStorage[i]
                }
            } else {
                selfWord = 0
            }

            let otherWord: UInt
            if i < otherWordCount {
                if let heapStorage = other._heapStorage {
                    otherWord = heapStorage[i]
                } else {
                    otherWord = other._inlineStorage[i]
                }
            } else {
                otherWord = 0
            }

            if result._heapStorage != nil {
                result._heapStorage![i] = selfWord ^ otherWord
            } else {
                result._inlineStorage[i] = selfWord ^ otherWord
            }
        }

        return result
    }
}

// MARK: - Set Relations

extension Set<Bit>.Packed.Small {
    /// Returns whether this set is a subset of another.
    @inlinable
    public func isSubset(of other: Self) -> Bool {
        let selfWordCount = _wordCount
        let otherWordCount = other._wordCount

        for i in 0..<selfWordCount {
            let selfWord: UInt
            if let heapStorage = _heapStorage {
                selfWord = heapStorage[i]
            } else {
                selfWord = _inlineStorage[i]
            }

            let otherWord: UInt
            if i < otherWordCount {
                if let heapStorage = other._heapStorage {
                    otherWord = heapStorage[i]
                } else {
                    otherWord = other._inlineStorage[i]
                }
            } else {
                otherWord = 0
            }

            if (selfWord & ~otherWord) != 0 {
                return false
            }
        }
        return true
    }

    /// Returns whether this set is a superset of another.
    @inlinable
    public func isSuperset(of other: Self) -> Bool {
        other.isSubset(of: self)
    }

    /// Returns whether this set is disjoint from another.
    @inlinable
    public func isDisjoint(with other: Self) -> Bool {
        let minWordCount = Swift.min(_wordCount, other._wordCount)

        for i in 0..<minWordCount {
            let selfWord: UInt
            if let heapStorage = _heapStorage {
                selfWord = heapStorage[i]
            } else {
                selfWord = _inlineStorage[i]
            }

            let otherWord: UInt
            if let heapStorage = other._heapStorage {
                otherWord = heapStorage[i]
            } else {
                otherWord = other._inlineStorage[i]
            }

            if (selfWord & otherWord) != 0 {
                return false
            }
        }
        return true
    }
}

// MARK: - Iteration

extension Set<Bit>.Packed.Small {
    /// Calls the given closure on each set bit index.
    @inlinable
    public func forEach(_ body: (Bit.Index) -> Void) {
        let wordCount = _wordCount

        for wordIndex in 0..<wordCount {
            var word: UInt
            if let heapStorage = _heapStorage {
                word = heapStorage[wordIndex]
            } else {
                word = _inlineStorage[wordIndex]
            }

            while word != 0 {
                let bitIndex = word.trailingZeroBitCount
                let globalIndex = wordIndex * Self._bitsPerWord + bitIndex
                if globalIndex < _capacity {
                    body(Bit.Index(__unchecked: (), position: globalIndex))
                }
                word &= word - 1
            }
        }
    }
}

// MARK: - Additional Properties

extension Set<Bit>.Packed.Small {
    /// The smallest element in the set, or `nil` if empty.
    @inlinable
    public var min: Bit.Index? {
        let wordCount = _wordCount

        for wordIndex in 0..<wordCount {
            let word: UInt
            if let heapStorage = _heapStorage {
                word = heapStorage[wordIndex]
            } else {
                word = _inlineStorage[wordIndex]
            }

            if word != 0 {
                let lowestBit = word.trailingZeroBitCount
                let element = wordIndex * Self._bitsPerWord + lowestBit
                return element < _capacity ? Bit.Index(__unchecked: (), position: element) : nil
            }
        }
        return nil
    }

    /// The largest element in the set, or `nil` if empty.
    @inlinable
    public var max: Bit.Index? {
        let wordCount = _wordCount

        for wordIndex in (0..<wordCount).reversed() {
            let word: UInt
            if let heapStorage = _heapStorage {
                word = heapStorage[wordIndex]
            } else {
                word = _inlineStorage[wordIndex]
            }

            if word != 0 {
                let highestBit = UInt.bitWidth - 1 - word.leadingZeroBitCount
                let element = wordIndex * Self._bitsPerWord + highestBit
                return element < _capacity ? Bit.Index(__unchecked: (), position: element) : nil
            }
        }
        return nil
    }
}

// MARK: - Sequence

extension Set<Bit>.Packed.Small: Sequence {
    /// An iterator over the elements of a small bit set.
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let inlineStorage: InlineArray<inlineWordCount, UInt>

        @usableFromInline
        let heapStorage: ContiguousArray<UInt>?

        @usableFromInline
        let capacity: Int

        @usableFromInline
        let wordCount: Int

        @usableFromInline
        var wordIndex: Int

        @usableFromInline
        var currentWord: UInt

        @usableFromInline
        init(
            inlineStorage: InlineArray<inlineWordCount, UInt>,
            heapStorage: ContiguousArray<UInt>?,
            capacity: Int
        ) {
            self.inlineStorage = inlineStorage
            self.heapStorage = heapStorage
            self.capacity = capacity
            self.wordCount = heapStorage?.count ?? inlineWordCount
            self.wordIndex = 0
            if let heap = heapStorage {
                self.currentWord = heap.isEmpty ? 0 : heap[0]
            } else {
                self.currentWord = inlineWordCount > 0 ? inlineStorage[0] : 0
            }
        }

        @inlinable
        public mutating func next() -> Bit.Index? {
            while currentWord == 0 {
                wordIndex += 1
                guard wordIndex < wordCount else { return nil }
                if let heap = heapStorage {
                    currentWord = heap[wordIndex]
                } else {
                    currentWord = inlineStorage[wordIndex]
                }
            }

            let bit = currentWord.trailingZeroBitCount
            currentWord &= currentWord &- 1  // Clear lowest set bit
            let element = wordIndex * UInt.bitWidth + bit
            return element < capacity ? Bit.Index(__unchecked: (), position: element) : nil
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(
            inlineStorage: _inlineStorage,
            heapStorage: _heapStorage,
            capacity: _capacity
        )
    }
}

// MARK: - Equatable

extension Set<Bit>.Packed.Small: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        let lhsWordCount = lhs._wordCount
        let rhsWordCount = rhs._wordCount
        let maxWordCount = Swift.max(lhsWordCount, rhsWordCount)

        for i in 0..<maxWordCount {
            let lhsWord: UInt
            if i < lhsWordCount {
                if let heapStorage = lhs._heapStorage {
                    lhsWord = heapStorage[i]
                } else {
                    lhsWord = lhs._inlineStorage[i]
                }
            } else {
                lhsWord = 0
            }

            let rhsWord: UInt
            if i < rhsWordCount {
                if let heapStorage = rhs._heapStorage {
                    rhsWord = heapStorage[i]
                } else {
                    rhsWord = rhs._inlineStorage[i]
                }
            } else {
                rhsWord = 0
            }

            if lhsWord != rhsWord {
                return false
            }
        }
        return true
    }
}

// MARK: - Hashable

extension Set<Bit>.Packed.Small: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        let wordCount = _wordCount
        for i in 0..<wordCount {
            let word: UInt
            if let heapStorage = _heapStorage {
                word = heapStorage[i]
            } else {
                word = _inlineStorage[i]
            }
            hasher.combine(word)
        }
    }
}

// MARK: - CustomStringConvertible

extension Set<Bit>.Packed.Small: CustomStringConvertible {
    public var description: String {
        let elements = Swift.Array(self.prefix(10))
        let suffix = count > 10 ? ", ..." : ""
        let spilledMarker = isSpilled ? " (spilled)" : ""
        return "Set<Bit>.Packed.Small<\(inlineWordCount)>(\(elements.map { String($0.position.rawValue) }.joined(separator: ", "))\(suffix))\(spilledMarker)"
    }
}
