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

import Finite_Primitives
import Index_Primitives
public import Set_Primitives_Core
public import Buffer_Linear_Inline_Primitives
public import Buffer_Linear_Primitive

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
    public var count: Index<Element>.Count { _buffer.count }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { _hashTable.isEmpty }

    /// Whether the set is at full capacity.
    @inlinable
    public var isFull: Bool { _hashTable.isFull }
}

// MARK: - Core Operations

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Returns the bounded index of the given element, or `nil` if not present.
    ///
    /// The returned index is guaranteed to be in [0, capacity).
    ///
    /// - Complexity: O(1) average, O(n) worst case.
    @inlinable
    public func index(_ element: borrowing Element) -> Index<Element>.Bounded<capacity>? {
        _hashTable.position(
            forHash: element.hashValue,
            context: element,
            equals: { idx, elem in _buffer[idx] == elem }
        )
    }

    /// Returns whether the set contains the given element.
    ///
    /// - Complexity: O(1) average, O(n) worst case.
    @inlinable
    public func contains(_ element: borrowing Element) -> Bool {
        _hashTable.position(
            forHash: element.hashValue,
            context: element,
            equals: { idx, elem in _buffer[idx] == elem }
        ) != nil
    }

    /// Inserts an element into the set.
    ///
    /// - Parameter element: The element to insert.
    /// - Returns: A tuple indicating whether insertion occurred and the element's bounded index.
    /// - Throws: ``Error/overflow`` if the set is full.
    /// - Complexity: O(1) average, O(n) worst case.
    @inlinable
    @discardableResult
    public mutating func insert(_ element: consuming Element) throws(__SetOrderedInlineError<Element>) -> (inserted: Bool, index: Index<Element>.Bounded<capacity>) {
        let hashValue = element.hashValue

        // Check for existing element
        if let existingPosition = _hashTable.position(
            forHash: hashValue,
            equals: { idx in
                _buffer[idx] == element
            }
        ) {
            return (false, existingPosition)
        }

        // Check capacity
        guard !_hashTable.isFull else {
            throw .overflow(.init())
        }

        // Insert at next available position (count < capacity since !isFull)
        let position: Index<Element>.Bounded<capacity> = .init(_buffer.count.map(Ordinal.init))!
        _ = _buffer.append(element)
        _hashTable.insert(_unchecked: (), position: position, hashValue: hashValue)

        return (true, position)
    }

    /// Removes an element from the set.
    ///
    /// - Parameter element: The element to remove.
    /// - Returns: The removed element, or `nil` if not present.
    /// - Complexity: O(n) due to element shifting.
    @inlinable
    @discardableResult
    public mutating func remove(_ element: borrowing Element) -> Element? {
        // Find and remove from hash table
        guard
            let removedPosition = _hashTable.remove(
                hashValue: element.hashValue,
                context: element,
                equals: { idx, elem in _buffer[idx] == elem }
            )
        else {
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
    public func element(at index: Index<Element>) throws(__SetOrderedInlineError<Element>) -> Element {
        guard index < count else {
            throw .bounds(.init(index: index, count: count))
        }
        return _buffer[index]
    }

    /// Accesses the element at a capacity-bounded index.
    ///
    /// The bounded index guarantees `index < capacity` at the type level.
    /// Only the `index < count` check remains as a runtime precondition
    /// (the slot must be initialized).
    @inlinable
    public func element(at index: Index<Element>.Bounded<capacity>) throws(__SetOrderedInlineError<Element>) -> Element {
        let unbounded = Index<Element>(index)
        guard unbounded < count else {
            throw .bounds(.init(index: Index<Element>(index), count: count))
        }
        return _buffer[index]
    }

    /// Subscript access to elements by index.
    @inlinable
    public subscript(index: Index<Element>) -> Element {
        precondition(index < count, "Index out of bounds")
        return _buffer[index]
    }

    /// Subscript access to elements by capacity-bounded index.
    ///
    /// - index >= 0: guaranteed by `Ordinal` (non-negative by construction)
    /// - index < capacity: guaranteed by `Finite<capacity>` (bounded by type)
    /// - index < count: checked at runtime (count is runtime state)
    @inlinable
    public subscript(index: Index<Element>.Bounded<capacity>) -> Element {
        precondition(index < count, "Index out of bounds")
        return _buffer[index]
    }
}

// MARK: - First/Last Accessors

extension Set_Primitives_Core.Set.Ordered.Static {
    /// The first element, or `nil` if the set is empty.
    @inlinable
    public var first: Element? {
        count > .zero ? _buffer[.zero] : nil
    }

    /// The last element, or `nil` if the set is empty.
    @inlinable
    public var last: Element? {
        guard count > .zero else { return nil }
        let lastIndex = count.subtract.saturating(.one).map(Ordinal.init)
        return _buffer[lastIndex]
    }
}

// MARK: - Borrowed Element Access

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Accesses the element at the given index via closure.
    @inlinable
    public func withElement<R>(at index: Index<Element>, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(_buffer[index])
    }

    /// Accesses the element at a capacity-bounded index via closure.
    @inlinable
    public func withElement<R>(at index: Index<Element>.Bounded<capacity>, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(_buffer[index])
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
            body(_buffer.remove.first())
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
