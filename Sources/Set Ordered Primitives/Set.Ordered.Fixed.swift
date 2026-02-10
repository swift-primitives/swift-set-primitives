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

// Note: Set.Ordered.Fixed is declared inside Set.Ordered (in Set.swift).
// This file contains only extensions to Set.Ordered.Fixed.

// MARK: - Properties

extension Set_Primitives_Core.Set.Ordered.Fixed {
    /// The number of elements in the set.
    @inlinable
    public var count: Index<Element>.Count { buffer.count }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { buffer.isEmpty }

    /// Whether the set is at full capacity.
    @inlinable
    public var isFull: Bool { buffer.count >= maximumCapacity }

    /// The maximum capacity (alias for API consistency).
    @inlinable
    public var capacity: Index<Element>.Count { maximumCapacity }
}

// MARK: - Coordinated CoW

extension Set_Primitives_Core.Set.Ordered.Fixed where Element: Copyable {
    /// Ensures both buffer and hash table are uniquely owned.
    @usableFromInline
    @inline(__always)
    mutating func makeUnique() {
        buffer.ensureUnique()
        hashTable.ensureUnique()
    }
}

// MARK: - Core Operations (Copyable elements)

extension Set_Primitives_Core.Set.Ordered.Fixed where Element: Copyable {
    /// Returns the index of the given element, or `nil` if not present.
    @inlinable
    public func index(_ element: Element) -> Index<Element>? {
        hashTable.position(
            forHash: element.hashValue,
            equals: { idx in buffer[idx] == element }
        )
    }

    /// Inserts an element into the set.
    ///
    /// - Parameter element: The element to insert.
    /// - Returns: A tuple indicating whether insertion occurred and the element's index.
    /// - Throws: ``Error/overflow`` if the set is full.
    @inlinable
    @discardableResult
    public mutating func insert(_ element: Element) throws(__SetOrderedFixedError) -> (inserted: Bool, index: Index<Element>) {
        if let existing = hashTable.position(
            forHash: element.hashValue,
            equals: { idx in buffer[idx] == element }
        ) {
            return (false, existing)
        }

        let currentCount = buffer.count
        guard currentCount < maximumCapacity else {
            throw .overflow(.init())
        }
        makeUnique()
        let index = currentCount.map(Ordinal.init)
        _ = buffer.append(element)
        hashTable.insert(__unchecked: (), position: index, hashValue: element.hashValue)

        return (true, index)
    }

    /// Removes an element from the set.
    ///
    /// - Parameter element: The element to remove.
    /// - Returns: The removed element, or `nil` if not present.
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        makeUnique()

        guard let removedPosition = hashTable.remove(
            hashValue: element.hashValue,
            equals: { idx in buffer[idx] == element }
        ) else {
            return nil
        }

        let removed = buffer.remove(at: removedPosition)
        hashTable.positions.decrement(after: removedPosition)

        return removed
    }

    /// Returns whether the set contains the given element.
    @inlinable
    public func contains(_ element: Element) -> Bool {
        hashTable.position(
            forHash: element.hashValue,
            equals: { idx in buffer[idx] == element }
        ) != nil
    }

    /// Removes all elements from the set.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        makeUnique()
        buffer.removeAll()
        hashTable.remove.all(keepingCapacity: keepingCapacity)
    }
}

// MARK: - Element Access (Copyable only)

extension Set_Primitives_Core.Set.Ordered.Fixed where Element: Copyable {
    /// Accesses the element at the specified index.
    @inlinable
    public func element(at index: Index<Element>) throws(__SetOrderedFixedError) -> Element {
        guard index < count else {
            throw .bounds(.init(index: Int(bitPattern: index.position), count: Int(bitPattern: count)))
        }
        return buffer[index]
    }

    /// Subscript access to elements by index.
    @inlinable
    public subscript(index: Index<Element>) -> Element {
        precondition(index < count, "Index out of bounds")
        return buffer[index]
    }
}

// MARK: - First/Last Accessors (Copyable only)

extension Set_Primitives_Core.Set.Ordered.Fixed where Element: Copyable {
    /// The first element, or `nil` if the set is empty.
    @inlinable
    public var first: Element? {
        count > .zero ? buffer[.zero] : nil
    }

    /// The last element, or `nil` if the set is empty.
    @inlinable
    public var last: Element? {
        guard count > .zero else { return nil }
        let lastIndex = count.subtract.saturating(.one).map(Ordinal.init)
        return buffer[lastIndex]
    }
}

// MARK: - Borrowed Element Access

extension Set_Primitives_Core.Set.Ordered.Fixed {
    /// Accesses the element at the given index via closure.
    @inlinable
    public func withElement<R>(at index: Index<Element>, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(buffer[index])
    }

    /// Iterates over all elements in the set.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        let count = buffer.count
        guard count > .zero else { return }
        var index: Index<Element> = .zero
        let end = count.map(Ordinal.init)
        while index < end {
            try body(buffer[index])
            index += .one
        }
    }

    /// Removes and consumes all elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        guard buffer.count > .zero else { return }
        while !buffer.isEmpty {
            body(buffer.consumeFront())
        }
        hashTable.remove.all(keepingCapacity: true)
    }
}

// MARK: - Span Access

extension Set_Primitives_Core.Set.Ordered.Fixed {
    /// Provides read-only span access to the set's elements in insertion order.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        try body(buffer.span)
    }

    /// Provides mutable span access to the set's elements in insertion order.
    ///
    /// - Warning: Modifying elements through this span may invalidate the hash table.
    ///   Only use for in-place updates that preserve element identity/hash.
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (inout MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R where Element: Copyable {
        makeUnique()
        var span = buffer.mutableSpan
        return try body(&span)
    }
}

// MARK: - Buffer Access (Escape Hatch for C Interop)

@_spi(Unsafe)
extension Set_Primitives_Core.Set.Ordered.Fixed {
    /// Provides read-only access to the underlying contiguous storage.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let span = buffer.span
        return try unsafe span.withUnsafeBufferPointer(body)
    }

    /// Provides mutable access to the underlying contiguous storage.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R where Element: Copyable {
        makeUnique()
        var span = buffer.mutableSpan
        return try unsafe span.withUnsafeMutableBufferPointer(body)
    }
}

// MARK: - Hash.Protocol Conformance

extension Set_Primitives_Core.Set.Ordered.Fixed: Hash.`Protocol` {
    /// Compares two Fixed ordered sets for element-wise equality.
    @inlinable
    public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        let count = lhs.count
        guard count > .zero else { return true }
        var index: Index<Element> = .zero
        let end = count.map(Ordinal.init)
        while index < end {
            if lhs.buffer[index] != rhs.buffer[index] {
                return false
            }
            index += .one
        }
        return true
    }

    /// Hashes the essential components of this set by feeding them into the given hasher.
    @inlinable
    public borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(Int(bitPattern: count))
        guard count > .zero else { return }
        var index: Index<Element> = .zero
        let end = count.map(Ordinal.init)
        while index < end {
            buffer[index].hash(into: &hasher)
            index += .one
        }
    }
}
