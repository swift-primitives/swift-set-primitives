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
import Cardinal_Primitives

// ============================================================================
// MARK: - Properties
// ============================================================================

extension Set.Ordered {
    /// The number of elements in the set.
    @inlinable
    public var count: Index<Element>.Count { buffer.count }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { buffer.isEmpty }

    /// The current capacity of the set.
    @inlinable
    public var capacity: Index<Element>.Count { buffer.capacity }
}

// ============================================================================
// MARK: - Reserve Capacity
// ============================================================================

extension Set.Ordered {
    /// Reserves enough space to store the specified number of elements.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Index<Element>.Count) {
        buffer.reserveCapacity(minimumCapacity)
    }
}

// ============================================================================
// MARK: - Borrowed Element Access
// ============================================================================

extension Set.Ordered {
    /// Accesses the element at the given index via closure.
    ///
    /// - Parameters:
    ///   - index: The index of the element.
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The result of the closure.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withElement<R>(at index: Index<Element>, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(buffer[index])
    }

    /// Accesses the element at the given index via closure, with typed error on bounds failure.
    ///
    /// - Parameters:
    ///   - index: The index of the element.
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The result of the closure.
    /// - Throws: ``Set/Ordered/Error/bounds(_:)`` if the index is out of bounds.
    @inlinable
    public func withElement<R>(at index: Index<Element>, _ body: (borrowing Element) throws(__SetOrderedError<Element>) -> R) throws(__SetOrderedError<Element>) -> R {
        guard index < count else {
            throw .bounds(.init(index: index, count: count))
        }
        return try body(buffer[index])
    }

    /// Returns whether the set contains the given element.
    @inlinable
    public func contains(_ element: borrowing Element) -> Bool {
        let count = buffer.count
        guard count > .zero else { return false }
        var index: Index<Element> = .zero
        let end = count.map(Ordinal.init)
        while index < end {
            if buffer[index] == element { return true }
            index += .one
        }
        return false
    }

    /// Iterates over all elements in the set.
    ///
    /// - Parameter body: A closure that receives each borrowed element.
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
}

// ============================================================================
// MARK: - Span Access
// ============================================================================

extension Set.Ordered {
    /// Provides read-only span access to the set's elements in insertion order.
    ///
    /// - Parameter body: A closure that receives the span.
    /// - Returns: The value returned by the closure.
    /// - Throws: Rethrows any error thrown by the closure.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        try body(buffer.span)
    }
}

// ============================================================================
// MARK: - Buffer Access (Escape Hatch for C Interop)
// ============================================================================

@_spi(Unsafe)
extension Set.Ordered {
    /// Provides read-only access to the underlying contiguous storage.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let span = buffer.span
        return try unsafe span.withUnsafeBufferPointer(body)
    }
}

