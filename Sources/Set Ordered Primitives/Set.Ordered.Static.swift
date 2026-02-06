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
public import Index_Primitives

// Note: Set.Ordered.Static is declared inside Set.Ordered (in Set.swift).
// This file contains only extensions to Set.Ordered.Static.
//
// ## Architecture
//
// Set.Ordered.Static composes two lower-level primitives:
// - Storage.Inline<capacity>: Element storage with 64-byte slots
// - Hash.Table.Static<capacity>: O(1) position lookup by hash
//
// This layering ensures single responsibility:
// - Hash table logic lives in Hash.Table.Static
// - Storage management lives in Storage.Inline
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
            _storage.withElement(at: idx) { stored in
                stored == element
            }
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
            _storage.withElement(at: idx) { stored in
                stored == element
            }
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
            _storage.withElement(at: idx) { stored in
                stored == element
            }
        }) {
            return (false, Int(bitPattern: existingPosition.position.rawValue))
        }

        // Check capacity
        guard !_hashTable.isFull else {
            throw .overflow(.init())
        }

        // Insert at next available position
        let position = Index<Element>(Ordinal(_hashTable.count.rawValue.rawValue))
        _storage.initialize(to: element, at: position)
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
            _storage.withElement(at: idx) { stored in
                stored == element
            }
        }) else {
            return nil
        }

        // Move element out of storage
        let removed = _storage.move(at: removedPosition)

        // Get count before removal (hash table already decremented)
        let countBeforeRemoval = Index<Element>.Count(Cardinal(_hashTable.count.rawValue.rawValue + 1))

        // Shift remaining elements left
        _storage.shift.left(removedAt: removedPosition, count: countBeforeRemoval)

        // Update positions in hash table for shifted elements
        _hashTable.decrementPositions(after: removedPosition)

        return removed
    }

    /// Removes all elements from the set.
    @inlinable
    public mutating func clear() {
        let currentCount = _hashTable.count
        guard currentCount > .zero else { return }
        _storage.deinitialize(count: currentCount)
        _hashTable.removeAll()
    }
}

// MARK: - Element Access

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Accesses the element at the specified index.
    @inlinable
    public mutating func element(at index: Int) throws(__SetOrderedInlineError) -> Element {
        guard index >= 0 && index < count else {
            throw .bounds(.init(index: index, count: count))
        }
        let idx = Index<Element>(Ordinal(UInt(index)))
        return _storage.withElement(at: idx) { $0 }
    }

}

// MARK: - First/Last Accessors

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Returns the first element, or `nil` if the set is empty.
    @inlinable
    public func getFirst() -> Element? {
        guard Int(bitPattern: _hashTable.count) > 0 else { return nil }
        return _storage.withElement(at: .zero) { $0 }
    }

    /// Returns the last element, or `nil` if the set is empty.
    @inlinable
    public func getLast() -> Element? {
        let c = Int(bitPattern: _hashTable.count)
        guard c > 0 else { return nil }
        let lastIndex = Index<Element>(Ordinal(UInt(c - 1)))
        return _storage.withElement(at: lastIndex) { $0 }
    }
}

// MARK: - Borrowed Element Access

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Accesses the element at the given index via closure.
    @inlinable
    public func withElement<R>(at index: Int, _ body: (borrowing Element) -> R) -> R {
        precondition(index >= 0 && index < Int(bitPattern: _hashTable.count), "Index out of bounds")
        let idx = Index<Element>(Ordinal(UInt(index)))
        return _storage.withElement(at: idx, body)
    }

    /// Iterates over all elements in the set.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        try _storage.forEach(count: _hashTable.count, body)
    }

    /// Removes and consumes all elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        let currentCount = _hashTable.count
        guard currentCount > .zero else { return }

        // Move each element out and pass to body
        (.zero..<currentCount).forEach { idx in
            let element = _storage.move(at: idx)
            body(element)
        }

        // Clear hash table
        _hashTable.removeAll()
    }
}

// MARK: - Span Access Note
//
// Storage.Inline uses 64-byte slots to support ~Copyable elements.
// This strided layout is incompatible with Span's dense expectation.
// Use forEach or withElement for iteration instead of Span access.
