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
        static var bitsPerWord: Int { UInt.bitWidth }

        /// The number of bits that can be stored inline without heap allocation.
        @inlinable
        public static var inlineCapacity: Int { inlineWordCount * bitsPerWord }

        @usableFromInline
        var inlineStorage: InlineArray<inlineWordCount, UInt>

        @usableFromInline
        var storedCapacity: Int

        @usableFromInline
        var heapStorage: ContiguousArray<UInt>?

        /// Creates an empty small bit set.
        @inlinable
        public init() {
            self.inlineStorage = InlineArray(repeating: 0)
            self.storedCapacity = Self.inlineCapacity
            self.heapStorage = nil
        }

        /// Internal initializer for constructing from storage.
        @usableFromInline
        init(
            __inlineStorage: InlineArray<inlineWordCount, UInt>,
            heapStorage: ContiguousArray<UInt>?,
            storedCapacity: Int
        ) {
            self.inlineStorage = __inlineStorage
            self.heapStorage = heapStorage
            self.storedCapacity = storedCapacity
        }

        /// Whether the set has spilled to heap storage.
        @inlinable
        public var isSpilled: Bool { heapStorage != nil }
    }
}

// MARK: - Properties

extension Set<Bit>.Packed.Small {
    /// The current capacity of the set.
    @inlinable
    public var capacity: Int { storedCapacity }

    /// The number of bits set (popcount).
    @inlinable
    public var count: Int {
        if let heapStorage = heapStorage {
            var total = 0
            for word in heapStorage {
                total += word.nonzeroBitCount
            }
            return total
        } else {
            var total = 0
            for i in 0..<inlineWordCount {
                total += inlineStorage[i].nonzeroBitCount
            }
            return total
        }
    }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool {
        if let heapStorage = heapStorage {
            for word in heapStorage {
                if word != 0 { return false }
            }
            return true
        } else {
            for i in 0..<inlineWordCount {
                if inlineStorage[i] != 0 { return false }
            }
            return true
        }
    }

    @usableFromInline
    var wordCount: Int {
        if let heapStorage = heapStorage {
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
        let i = index.position
        guard i >= 0 && i < capacity else { return false }
        let wordIndex = i / Self.bitsPerWord
        let bitIndex = i % Self.bitsPerWord
        let mask: UInt = 1 << bitIndex

        if let heapStorage = heapStorage {
            return (heapStorage[wordIndex] & mask) != 0
        } else {
            return (inlineStorage[wordIndex] & mask) != 0
        }
    }

    /// Returns whether the set contains the given integer index.
    @inlinable
    public func contains(_ index: Int) -> Bool {
        guard index >= 0 && index < capacity else { return false }
        let wordIndex = index / Self.bitsPerWord
        let bitIndex = index % Self.bitsPerWord
        let mask: UInt = 1 << bitIndex

        if let heapStorage = heapStorage {
            return (heapStorage[wordIndex] & mask) != 0
        } else {
            return (inlineStorage[wordIndex] & mask) != 0
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
        let i = index.position
        guard i >= 0 else {
            throw .bounds(.init(index: i, capacity: capacity))
        }

        // Spill to heap if needed
        if i >= capacity {
            spillToHeap(toInclude: i)
        }

        let wordIndex = i / Self.bitsPerWord
        let bitIndex = i % Self.bitsPerWord
        let mask: UInt = 1 << bitIndex

        if heapStorage != nil {
            let wasSet = (heapStorage![wordIndex] & mask) != 0
            heapStorage![wordIndex] |= mask
            return !wasSet
        } else {
            let wasSet = (inlineStorage[wordIndex] & mask) != 0
            inlineStorage[wordIndex] |= mask
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
        let i = index.position
        guard i >= 0 && i < capacity else {
            throw .bounds(.init(index: i, capacity: capacity))
        }

        let wordIndex = i / Self.bitsPerWord
        let bitIndex = i % Self.bitsPerWord
        let mask: UInt = 1 << bitIndex

        if heapStorage != nil {
            let wasSet = (heapStorage![wordIndex] & mask) != 0
            heapStorage![wordIndex] &= ~mask
            return wasSet
        } else {
            let wasSet = (inlineStorage[wordIndex] & mask) != 0
            inlineStorage[wordIndex] &= ~mask
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
        if heapStorage != nil {
            for i in 0..<heapStorage!.count {
                heapStorage![i] = 0
            }
        } else {
            for i in 0..<inlineWordCount {
                inlineStorage[i] = 0
            }
        }
    }

    /// Removes all elements and resets to inline storage mode.
    @inlinable
    public mutating func clear() {
        heapStorage = nil
        storedCapacity = Self.inlineCapacity
        for i in 0..<inlineWordCount {
            inlineStorage[i] = 0
        }
    }

    @usableFromInline
    mutating func spillToHeap(toInclude index: Int) {
        let newCapacity = index + 1
        let newWordCount = (newCapacity + Self.bitsPerWord - 1) / Self.bitsPerWord

        if var existingHeap = heapStorage {
            // Already spilled - grow the heap storage
            let oldWordCount = existingHeap.count
            if newWordCount > oldWordCount {
                existingHeap.reserveCapacity(newWordCount)
                for _ in oldWordCount..<newWordCount {
                    existingHeap.append(0)
                }
                heapStorage = existingHeap
            }
            storedCapacity = newCapacity
        } else {
            // First spill - copy from inline to heap
            var newStorage = ContiguousArray<UInt>()
            newStorage.reserveCapacity(newWordCount)

            // Copy inline storage to heap
            for i in 0..<inlineWordCount {
                newStorage.append(inlineStorage[i])
            }

            // Add new words
            for _ in inlineWordCount..<newWordCount {
                newStorage.append(0)
            }

            heapStorage = newStorage
            storedCapacity = newCapacity
        }
    }
}




// MARK: - Additional Properties

extension Set<Bit>.Packed.Small {
    /// The smallest element in the set, or `nil` if empty.
    @inlinable
    public var min: Bit.Index? {
        let wordCount = wordCount

        for wordIndex in 0..<wordCount {
            let word: UInt
            if let heapStorage = heapStorage {
                word = heapStorage[wordIndex]
            } else {
                word = inlineStorage[wordIndex]
            }

            if word != 0 {
                let lowestBit = word.trailingZeroBitCount
                let element = wordIndex * Self.bitsPerWord + lowestBit
                return element < capacity ? Bit.Index(__unchecked: (), position: element) : nil
            }
        }
        return nil
    }

    /// The largest element in the set, or `nil` if empty.
    @inlinable
    public var max: Bit.Index? {
        let wordCount = wordCount

        for wordIndex in (0..<wordCount).reversed() {
            let word: UInt
            if let heapStorage = heapStorage {
                word = heapStorage[wordIndex]
            } else {
                word = inlineStorage[wordIndex]
            }

            if word != 0 {
                let highestBit = UInt.bitWidth - 1 - word.leadingZeroBitCount
                let element = wordIndex * Self.bitsPerWord + highestBit
                return element < capacity ? Bit.Index(__unchecked: (), position: element) : nil
            }
        }
        return nil
    }
}

// MARK: - Equatable

extension Set<Bit>.Packed.Small: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        let lhsWordCount = lhs.wordCount
        let rhsWordCount = rhs.wordCount
        let maxWordCount = Swift.max(lhsWordCount, rhsWordCount)

        for i in 0..<maxWordCount {
            let lhsWord: UInt
            if i < lhsWordCount {
                if let heapStorage = lhs.heapStorage {
                    lhsWord = heapStorage[i]
                } else {
                    lhsWord = lhs.inlineStorage[i]
                }
            } else {
                lhsWord = 0
            }

            let rhsWord: UInt
            if i < rhsWordCount {
                if let heapStorage = rhs.heapStorage {
                    rhsWord = heapStorage[i]
                } else {
                    rhsWord = rhs.inlineStorage[i]
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
        let wordCount = wordCount
        for i in 0..<wordCount {
            let word: UInt
            if let heapStorage = heapStorage {
                word = heapStorage[i]
            } else {
                word = inlineStorage[i]
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
        return "Set<Bit>.Packed.Small<\(inlineWordCount)>(\(elements.map { String($0.position) }.joined(separator: ", "))\(suffix))\(spilledMarker)"
    }
}
