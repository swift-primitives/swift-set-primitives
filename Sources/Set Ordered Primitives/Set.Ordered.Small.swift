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
public import Ordinal_Primitives
public import Cardinal_Primitives
import Memory_Primitives_Core

// Note: Set.Ordered.Small is declared inside Set.Ordered (in Set.swift).
// This file contains only extensions to Set.Ordered.Small.
//
// ## Design Note
//
// Small sets compose Buffer<Element>.Linear.Small<inlineCapacity> for element
// storage. The buffer handles inline/heap dispatch internally. The set layer
// adds hash table management (activated on spill) and deduplication.
//
// - Inline mode: linear search O(n) for membership (no hash table overhead)
// - Heap mode: O(1) hash table lookup

// ============================================================================
// MARK: - Properties
// ============================================================================

extension Set_Primitives_Core.Set.Ordered.Small {
    /// The number of elements in the set.
    @inlinable
    public var count: Index<Element>.Count {
        _buffer.count
    }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { count == .zero }

    /// The current capacity of the set.
    @inlinable
    public var capacity: Index<Element>.Count {
        _buffer.capacity
    }
}

// ============================================================================
// MARK: - Core Operations (Copyable elements)
// ============================================================================

extension Set_Primitives_Core.Set.Ordered.Small where Element: Copyable {
    /// Returns the index of the given element, or `nil` if not present.
    @inlinable
    public mutating func index(_ element: Element) -> Index<Element>? {
        if isSpilled {
            return _heapHashTable!.position(
                forHash: element.hashValue,
                equals: { idx in _buffer[idx] == element }
            )
        } else {
            var idx: Index<Element> = .zero
            let end = _buffer.count.map(Ordinal.init)
            while idx < end {
                if _buffer[idx] == element { return idx }
                idx += .one
            }
            return nil
        }
    }

    /// Returns whether the set contains the given element.
    @inlinable
    public mutating func contains(_ element: Element) -> Bool {
        index(element) != nil
    }

    /// Inserts an element into the set.
    ///
    /// If inline storage is full, spills to heap automatically.
    @inlinable
    @discardableResult
    public mutating func insert(_ element: Element) -> (inserted: Bool, index: Index<Element>) {
        if let existing = index(element) {
            return (false, existing)
        }

        let wasSpilled = _buffer.isSpilled
        let index = _buffer.count.map(Ordinal.init)
        _buffer.append(element)

        if wasSpilled {
            _heapHashTable!.insert(__unchecked: (), position: index, hashValue: element.hashValue)
        } else if _buffer.isSpilled {
            _buildHashTable()
        }

        return (true, index)
    }

    /// Removes an element from the set.
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        if isSpilled {
            guard let removedPosition = _heapHashTable!.remove(
                hashValue: element.hashValue,
                equals: { idx in _buffer[idx] == element }
            ) else { return nil }

            let removed = _buffer.remove(at: removedPosition)

            // WORKAROUND: Extract hash table to local for .positions.decrement() call.
            // Direct `_heapHashTable!.positions.decrement(after:)` crashes the
            // DiagnoseStaticExclusivity SIL pass on generic ~Copyable structs.
            // WHEN TO REMOVE: When swiftlang/swift fixes exclusivity analysis for
            // mutating coroutine accessor chains on stored properties of ~Copyable generics.
            var ht = _heapHashTable!
            ht.positions.decrement(after: removedPosition)
            _heapHashTable = ht

            return removed
        } else {
            guard let idx = index(element) else { return nil }
            return _buffer.remove(at: idx)
        }
    }

    /// Removes all elements from the set.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        _buffer.remove.all(keepingCapacity: keepingCapacity)
        if keepingCapacity {
            // WORKAROUND: Extract hash table to local for .remove.all() call.
            // Direct `_heapHashTable?.remove.all(keepingCapacity:)` crashes the
            // DiagnoseStaticExclusivity SIL pass on generic ~Copyable structs.
            // WHEN TO REMOVE: When swiftlang/swift fixes exclusivity analysis for
            // mutating coroutine accessor chains on stored properties of ~Copyable generics.
            if var ht = _heapHashTable {
                ht.remove.all(keepingCapacity: true)
                _heapHashTable = ht
            }
        } else {
            _heapHashTable = nil
        }
    }
}

// ============================================================================
// MARK: - Build Hash Table
// ============================================================================

extension Set_Primitives_Core.Set.Ordered.Small where Element: Copyable {
    /// Builds a hash table over all elements after spill.
    @usableFromInline
    mutating func _buildHashTable() {
        let count = _buffer.count
        _heapHashTable = Hash.Table<Element>(minimumCapacity: count)
        var idx: Index<Element> = .zero
        let end = count.map(Ordinal.init)
        while idx < end {
            _heapHashTable!.insert(__unchecked: (), position: idx, hashValue: _buffer[idx].hashValue)
            idx += .one
        }
    }
}

// ============================================================================
// MARK: - Element Access (Copyable)
// ============================================================================

extension Set_Primitives_Core.Set.Ordered.Small where Element: Copyable {
    /// Accesses the element at the specified index, returning nil if out of bounds.
    @inlinable
    public func element(at index: Index<Element>) -> Element? {
        guard index < count else { return nil }
        return _buffer[index]
    }

    /// Accesses the element at the specified index, with typed error on bounds failure.
    @inlinable
    public func element(at index: Index<Element>) throws(__SetOrderedError<Element>) -> Element {
        guard index < count else {
            throw .bounds(.init(index: index, count: count))
        }
        return _buffer[index]
    }

    /// Subscript access to elements by index.
    @inlinable
    public subscript(index: Index<Element>) -> Element {
        precondition(index < count, "Index out of bounds")
        return _buffer[index]
    }
}

// ============================================================================
// MARK: - First/Last Accessors (Copyable)
// ============================================================================

extension Set_Primitives_Core.Set.Ordered.Small where Element: Copyable {
    /// The first element, or `nil` if the set is empty.
    @inlinable
    public var first: Element? {
        guard count > .zero else { return nil }
        return _buffer[.zero]
    }

    /// The last element, or `nil` if the set is empty.
    @inlinable
    public var last: Element? {
        guard count > .zero else { return nil }
        let lastIndex = count.subtract.saturating(.one).map(Ordinal.init)
        return _buffer[lastIndex]
    }
}

// ============================================================================
// MARK: - Borrowed Element Access
// ============================================================================

extension Set_Primitives_Core.Set.Ordered.Small {
    /// Accesses the element at the given index via closure.
    @inlinable
    public func withElement<R>(at index: Index<Element>, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(_buffer[index])
    }

    /// Accesses the element at the given index via closure, with typed error on bounds failure.
    @inlinable
    public func withElement<R>(at index: Index<Element>, _ body: (borrowing Element) throws(__SetOrderedError<Element>) -> R) throws(__SetOrderedError<Element>) -> R {
        guard index < count else {
            throw .bounds(.init(index: index, count: count))
        }
        return try body(_buffer[index])
    }

    /// Iterates over all elements in the set.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        let count = count
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
        guard count > .zero else { return }

        while !_buffer.isEmpty {
            body(_buffer.remove.first())
        }

        // WORKAROUND: Extract hash table to local for .remove.all() call.
        // Direct `_heapHashTable?.remove.all(keepingCapacity:)` crashes the
        // DiagnoseStaticExclusivity SIL pass on generic ~Copyable structs.
        // WHEN TO REMOVE: When swiftlang/swift fixes exclusivity analysis for
        // mutating coroutine accessor chains on stored properties of ~Copyable generics.
        if var ht = _heapHashTable {
            ht.remove.all(keepingCapacity: true)
            _heapHashTable = ht
        }
    }
}

// ============================================================================
// MARK: - Span Access (Closure-Based)
// ============================================================================

extension Set_Primitives_Core.Set.Ordered.Small {
    /// Safe, bounds-checked read access to contiguous storage via closure.
    ///
    /// Small sets use closure-based access because inline storage mode requires
    /// it (Span is ~Escapable and cannot be returned from property accessors
    /// without special compiler support).
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        try body(_buffer.span)
    }

    /// Safe, bounds-checked write access to contiguous storage via closure.
    ///
    /// - Warning: Modifying elements may invalidate uniqueness if the
    ///   modifications affect element equality/hash.
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (inout MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        var span = _buffer.mutableSpan
        return try body(&span)
    }
}

// ============================================================================
// MARK: - Buffer Access (Escape Hatch for C Interop)
// ============================================================================

@_spi(Unsafe)
extension Set_Primitives_Core.Set.Ordered.Small where Element: Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: Prefer ``withSpan(_:)`` for safe access.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe _buffer.withUnsafeBufferPointer(body)
    }

    /// Provides mutable access to the underlying contiguous storage.
    ///
    /// - Warning: Prefer ``withMutableSpan(_:)`` for safe access.
    /// - Warning: Modifying elements may invalidate uniqueness.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe _buffer.withUnsafeMutableBufferPointer(body)
    }
}
