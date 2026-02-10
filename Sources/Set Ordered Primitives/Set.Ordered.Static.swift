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
import Index_Primitives

// Note: Set.Ordered.Static is declared inside Set.Ordered (in Set.swift).
// This file contains only extensions to Set.Ordered.Static.
//
// ## Architecture
//
// Set.Ordered.Static composes two lower-level primitives:
// - Buffer.Linear.Inline<capacity>: Element storage
// - Hash.Table.Static<capacity>: O(1) position lookup by hash
//
// This layering ensures single responsibility:
// - Hash table logic lives in Hash.Table.Static
// - Buffer management lives in Buffer.Linear.Inline
// - Set provides the unified API

// MARK: - Properties

extension Set_Primitives_Core.Set.Ordered.Static {
    /// The number of elements in the set.
    @inlinable
    public var count: Int { Int(bitPattern: _hashTable.count) }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { _hashTable.isEmpty }

    /// Whether the set is at full capacity.
    @inlinable
    public var isFull: Bool { _hashTable.isFull }
}

// MARK: - Core Operations

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Returns the index of the given element, or `nil` if not present.
    ///
    /// - Complexity: O(1) average, O(n) worst case.
    @inlinable
    public mutating func index(_ element: Element) -> Int? {
        let hashValue = element.hashValue
        guard let position = _hashTable.position(forHash: hashValue, equals: { idx in
            _buffer[idx] == element
        }) else {
            return nil
        }
        return Int(bitPattern: position.position.rawValue)
    }

    /// Returns whether the set contains the given element.
    ///
    /// - Complexity: O(1) average, O(n) worst case.
    @inlinable
    public mutating func contains(_ element: Element) -> Bool {
        let hashValue = element.hashValue
        return _hashTable.contains(hashValue: hashValue, equals: { idx in
            _buffer[idx] == element
        })
    }

    /// Inserts an element into the set.
    ///
    /// - Parameter element: The element to insert.
    /// - Returns: A tuple indicating whether insertion occurred and the element's index.
    /// - Throws: ``Error/overflow`` if the set is full.
    /// - Complexity: O(1) average, O(n) worst case.
    @inlinable
    @discardableResult
    public mutating func insert(_ element: Element) throws(__SetOrderedInlineError) -> (inserted: Bool, index: Int) {
        let hashValue = element.hashValue

        // Check for existing element
        if let existingPosition = _hashTable.position(forHash: hashValue, equals: { idx in
            _buffer[idx] == element
        }) {
            return (false, Int(bitPattern: existingPosition.position.rawValue))
        }

        // Check capacity
        guard !_hashTable.isFull else {
            throw .overflow(.init())
        }

        // Insert at next available position
        let position = Index<Element>(Ordinal(_hashTable.count.rawValue.rawValue))
        _ = _buffer.append(element)
        _hashTable.insert(__unchecked: (), position: position, hashValue: hashValue)

        return (true, Int(bitPattern: position.position.rawValue))
    }

    /// Removes an element from the set.
    ///
    /// - Parameter element: The element to remove.
    /// - Returns: The removed element, or `nil` if not present.
    /// - Complexity: O(n) due to element shifting.
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        let hashValue = element.hashValue

        // Find and remove from hash table
        guard let removedPosition = _hashTable.remove(hashValue: hashValue, equals: { idx in
            _buffer[idx] == element
        }) else {
            return nil
        }

        // Remove element from buffer (shifts remaining elements left)
        let removed = _buffer.remove(at: removedPosition)

        // Update positions in hash table for shifted elements
        _hashTable.positions.decrement(after: removedPosition)

        return removed
    }

    /// Removes all elements from the set.
    @inlinable
    public mutating func clear() {
        guard _hashTable.count > .zero else { return }
        _buffer.removeAll()
        _hashTable.remove.all()
    }
}

// MARK: - Element Access

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Accesses the element at the specified index.
    @inlinable
    public func element(at index: Int) throws(__SetOrderedInlineError) -> Element {
        guard index >= 0 && index < count else {
            throw .bounds(.init(index: index, count: count))
        }
        let idx = Index<Element>(Ordinal(UInt(index)))
        return _buffer[idx]
    }
}

// MARK: - First/Last Accessors

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Returns the first element, or `nil` if the set is empty.
    @inlinable
    public func getFirst() -> Element? {
        guard Int(bitPattern: _hashTable.count) > 0 else { return nil }
        return _buffer[Index<Element>.zero]
    }

    /// Returns the last element, or `nil` if the set is empty.
    @inlinable
    public func getLast() -> Element? {
        let c = Int(bitPattern: _hashTable.count)
        guard c > 0 else { return nil }
        let lastIndex = Index<Element>(Ordinal(UInt(c - 1)))
        return _buffer[lastIndex]
    }
}

// MARK: - Borrowed Element Access

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Accesses the element at the given index via closure.
    @inlinable
    public func withElement<R>(at index: Int, _ body: (borrowing Element) -> R) -> R {
        precondition(index >= 0 && index < Int(bitPattern: _hashTable.count), "Index out of bounds")
        let idx = Index<Element>(Ordinal(UInt(index)))
        return body(_buffer[idx])
    }

    /// Iterates over all elements in the set.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        let count = _buffer.count
        guard count > .zero else { return }
        var index: Index<Element> = .zero
        let end = count.map(Ordinal.init)
        while index < end {
            try body(_buffer[index])
            index += .one
        }
    }

    /// Removes and consumes all elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        guard _hashTable.count > .zero else { return }

        while !_buffer.isEmpty {
            body(_buffer.consumeFront())
        }

        // Clear hash table
        _hashTable.remove.all()
    }
}

// MARK: - Span Access Note
//
// Storage.Inline uses 64-byte slots to support ~Copyable elements.
// This strided layout is incompatible with Span's dense expectation.
// Use forEach or withElement for iteration instead of Span access.
