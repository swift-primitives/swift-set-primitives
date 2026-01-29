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

// MARK: - Properties

extension Set<Bit>.Vector {
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

extension Set<Bit>.Vector {
    @inlinable
    public func contains(_ index: Bit.Index) -> Bool {
        let i = Int(bitPattern: index.position)
        guard i >= 0 && i < capacity else { return false }
        let wordIndex = i / Self.bitsPerWord
        let bitIndex = i % Self.bitsPerWord
        let mask: UInt = 1 << bitIndex
        return (storage[wordIndex] & mask) != 0
    }
}

// MARK: - Mutation

extension Set<Bit>.Vector {
    @inlinable
    @discardableResult
    public mutating func insert(_ index: Bit.Index) throws(__SetBitVectorError) -> Bool {
        let i = Int(bitPattern: index.position)
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
    public mutating func remove(_ index: Bit.Index) throws(__SetBitVectorError) -> Bool {
        let i = Int(bitPattern: index.position)
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


// MARK: - Additional Properties

extension Set<Bit>.Vector {
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
                return element < capacity ? Bit.Index(__unchecked: (), Ordinal(UInt(element))) : nil
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
                return element < capacity ? Bit.Index(__unchecked: (), Ordinal(UInt(element))) : nil
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

extension Set<Bit>.Vector {
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

extension Set<Bit>.Vector: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage == rhs.storage && lhs.storedCapacity == rhs.storedCapacity
    }
}

// MARK: - Hashable

extension Set<Bit>.Vector: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(storage)
        hasher.combine(storedCapacity)
    }
}

// MARK: - CustomStringConvertible

extension Set<Bit>.Vector: CustomStringConvertible {
    public var description: String {
        let elements = Swift.Array(self.prefix(10))
        let suffix = count > 10 ? ", ..." : ""
        return "Set<Bit>.Vector(\(elements.map { "\($0.position)" }.joined(separator: ", "))\(suffix))"
    }
}
