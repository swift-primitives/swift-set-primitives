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
public import Ordinal_Primitives
public import Cardinal_Primitives
public import Memory_Primitives_Core

// Note: Set.Ordered.Small is declared inside Set.Ordered (in Set.swift).
// This file contains only extensions to Set.Ordered.Small.
//
// ## Design Note
//
// Small sets use inline storage until capacity is exceeded, then spill to heap.
// - Inline mode: linear search O(n) for membership (no hash table overhead)
// - Heap mode: O(1) hash table lookup
//
// ## Composition
//
// Inline: Buffer<Element>.Linear.Inline<inlineCapacity>         (no hash table)
// Heap:   Buffer<Element>.Linear + Hash.Table<Element>          (after spill)

// ============================================================================
// MARK: - Properties
// ============================================================================

extension Set_Primitives_Core.Set.Ordered.Small {
    /// The number of elements in the set.
    @inlinable
    public var count: Index<Element>.Count {
        isSpilled ? _heapBuffer!.count : _inlineBuffer.count
    }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { count == .zero }

    /// The current capacity of the set.
    @inlinable
    public var capacity: Index<Element>.Count {
        isSpilled ? _heapBuffer!.capacity : Index<Element>.Count(Cardinal(UInt(inlineCapacity)))
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
                equals: { idx in _heapBuffer![idx] == element }
            )
        } else {
            var idx: Index<Element> = .zero
            let end = _inlineBuffer.count.map(Ordinal.init)
            while idx < end {
                if _inlineBuffer[idx] == element { return idx }
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

        if isSpilled {
            let index = _heapBuffer!.count.map(Ordinal.init)
            _heapBuffer!.append(element)
            _heapHashTable!.insert(__unchecked: (), position: index, hashValue: element.hashValue)
            return (true, index)
        } else if !_inlineBuffer.isFull {
            let index = _inlineBuffer.count.map(Ordinal.init)
            _ = _inlineBuffer.append(element)
            return (true, index)
        } else {
            spillToHeap()
            let index = _heapBuffer!.count.map(Ordinal.init)
            _heapBuffer!.append(element)
            _heapHashTable!.insert(__unchecked: (), position: index, hashValue: element.hashValue)
            return (true, index)
        }
    }

    /// Removes an element from the set.
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        if isSpilled {
            guard let removedPosition = _heapHashTable!.remove(
                hashValue: element.hashValue,
                equals: { idx in _heapBuffer![idx] == element }
            ) else { return nil }

            let removed = _heapBuffer!.remove(at: removedPosition)
            _heapHashTable!.positions.decrement(after: removedPosition)
            return removed
        } else {
            guard let idx = index(element) else { return nil }
            return _inlineBuffer.remove(at: idx)
        }
    }

    /// Removes all elements from the set.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        if isSpilled {
            _heapBuffer!.removeAll()
            if keepingCapacity {
                _heapHashTable!.remove.all(keepingCapacity: true)
            } else {
                _heapHashTable!.remove.all(keepingCapacity: false)
                _heapBuffer = nil
                _heapHashTable = nil
            }
        } else {
            _inlineBuffer.removeAll()
        }
    }
}

// ============================================================================
// MARK: - Spill to Heap
// ============================================================================

extension Set_Primitives_Core.Set.Ordered.Small where Element: Copyable {
    /// Copies inline elements to heap storage and activates hash table.
    @usableFromInline
    mutating func spillToHeap() {
        let currentCount = _inlineBuffer.count
        let newCapacity = Index<Element>.Count(Cardinal(UInt(inlineCapacity * 2)))
        var newBuffer = Buffer<Element>.Linear(minimumCapacity: newCapacity)
        var newHashTable = Hash.Table<Element>(minimumCapacity: newCapacity)

        var idx: Index<Element> = .zero
        let end = currentCount.map(Ordinal.init)
        while idx < end {
            let element = _inlineBuffer[idx]
            let position = newBuffer.count.map(Ordinal.init)
            newBuffer.append(element)
            newHashTable.insert(__unchecked: (), position: position, hashValue: element.hashValue)
            idx += .one
        }
        _inlineBuffer.removeAll()

        _heapBuffer = newBuffer
        _heapHashTable = newHashTable
    }
}

// ============================================================================
// MARK: - Element Access (Copyable)
// ============================================================================

extension Set_Primitives_Core.Set.Ordered.Small where Element: Copyable {
    /// Accesses the element at the specified index.
    @inlinable
    public func element(at index: Index<Element>) -> Element? {
        guard index < count else { return nil }
        if isSpilled {
            return _heapBuffer![index]
        } else {
            return _inlineBuffer[index]
        }
    }

    /// Subscript access to elements by index.
    @inlinable
    public subscript(index: Index<Element>) -> Element {
        precondition(index < count, "Index out of bounds")
        if isSpilled {
            return _heapBuffer![index]
        } else {
            return _inlineBuffer[index]
        }
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
        if isSpilled {
            return _heapBuffer![.zero]
        } else {
            return _inlineBuffer[.zero]
        }
    }

    /// The last element, or `nil` if the set is empty.
    @inlinable
    public var last: Element? {
        guard count > .zero else { return nil }
        let lastIndex = count.subtract.saturating(.one).map(Ordinal.init)
        if isSpilled {
            return _heapBuffer![lastIndex]
        } else {
            return _inlineBuffer[lastIndex]
        }
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
        if isSpilled {
            return body(_heapBuffer![index])
        } else {
            return body(_inlineBuffer[index])
        }
    }

    /// Iterates over all elements in the set.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        let count = count
        guard count > .zero else { return }
        var index: Index<Element> = .zero
        let end = count.map(Ordinal.init)
        while index < end {
            if isSpilled {
                try body(_heapBuffer![index])
            } else {
                try body(_inlineBuffer[index])
            }
            index += .one
        }
    }

    /// Removes and consumes all elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        guard count > .zero else { return }

        if isSpilled {
            while !_heapBuffer!.isEmpty {
                body(_heapBuffer!.consumeFront())
            }
            _heapHashTable!.remove.all(keepingCapacity: true)
        } else {
            while !_inlineBuffer.isEmpty {
                body(_inlineBuffer.consumeFront())
            }
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
        if isSpilled {
            try body(_heapBuffer!.span)
        } else {
            try body(_inlineBuffer.span)
        }
    }

    /// Safe, bounds-checked write access to contiguous storage via closure.
    ///
    /// - Warning: Modifying elements may invalidate uniqueness if the
    ///   modifications affect element equality/hash.
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (inout MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        if isSpilled {
            var span = _heapBuffer!.mutableSpan
            return try body(&span)
        } else {
            var span = _inlineBuffer.mutableSpan
            return try body(&span)
        }
    }
}

// ============================================================================
// MARK: - Buffer Access (Escape Hatch for C Interop)
// ============================================================================

@_spi(Unsafe)
extension Set_Primitives_Core.Set.Ordered.Small {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: Prefer ``withSpan(_:)`` for safe access.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        if count > .zero {
            if isSpilled {
                let span = _heapBuffer!.span
                return try unsafe span.withUnsafeBufferPointer(body)
            } else {
                let span = _inlineBuffer.span
                return try unsafe span.withUnsafeBufferPointer(body)
            }
        } else {
            let nilPtr: UnsafePointer<Element>? = nil
            return try unsafe body(UnsafeBufferPointer(start: nilPtr, count: 0))
        }
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
        if count > .zero {
            if isSpilled {
                var span = _heapBuffer!.mutableSpan
                return try unsafe span.withUnsafeMutableBufferPointer(body)
            } else {
                var span = _inlineBuffer.mutableSpan
                return try unsafe span.withUnsafeMutableBufferPointer(body)
            }
        } else {
            let nilPtr: UnsafeMutablePointer<Element>? = nil
            return try unsafe body(UnsafeMutableBufferPointer(start: nilPtr, count: 0))
        }
    }
}
