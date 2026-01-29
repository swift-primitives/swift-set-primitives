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

// ============================================================================
// MARK: - Properties
// ============================================================================

extension Set.Ordered {
    /// The number of elements in the set.
    @inlinable
    public var count: Index<Element>.Count { elementStorage.count }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { elementStorage.count == .zero }

    /// The current capacity of the set.
    @inlinable
    public var capacity: Index<Element>.Count {
        Index<Element>.Count(Cardinal(UInt(elementStorage.capacity)))
    }
}

// ============================================================================
// MARK: - Hash Table Operations
// ============================================================================

extension Set.Ordered {
    /// Finds the position for an element with the given hash value.
    @usableFromInline
    func findPosition(forHash hashValue: Int, equals: (Index<Element>) -> Bool) -> Index<Element>? {
        hashTable.position(forHash: hashValue, equals: equals)
    }

    /// Inserts a position into the hash table without checking for duplicates.
    @usableFromInline
    mutating func insertPosition(position: Index<Element>, hashValue: Int) {
        hashTable.insert(__unchecked: (), position: position, hashValue: hashValue)
    }

    /// Removes a position from the hash table.
    @usableFromInline
    mutating func removePosition(hashValue: Int, equals: (Index<Element>) -> Bool) -> Index<Element>? {
        hashTable.remove(hashValue: hashValue, equals: equals)
    }

    /// Updates positions after an element is removed from element storage.
    @usableFromInline
    mutating func decrementPositions(after removedPosition: Index<Element>) {
        hashTable.decrementPositions(after: removedPosition)
    }

    /// Removes all entries from the hash table.
    @usableFromInline
    mutating func clearIndices(keepingCapacity: Bool) {
        hashTable.removeAll(keepingCapacity: keepingCapacity)
    }
}

// ============================================================================
// MARK: - Capacity Management
// ============================================================================

extension Set.Ordered {
    @usableFromInline
    mutating func ensureCapacity(_ minimumCapacity: Index<Element>.Count) {
        let currentCapacity = Index<Element>.Count(Cardinal(UInt(elementStorage.capacity)))
        guard currentCapacity < minimumCapacity else { return }

        let minCapInt = Int(bitPattern: minimumCapacity)
        let currentCapInt = elementStorage.capacity
        let newCapacity = Index<Element>.Count(Cardinal(UInt(Swift.max(minCapInt, currentCapInt * 2, 4))))
        let newStorage = Storage<Element>.create(minimumCapacity: newCapacity)
        let currentCount = elementStorage.count

        elementStorage.move(to: newStorage, count: currentCount)
        newStorage.count = currentCount
        elementStorage = newStorage
    }

    /// Reserves enough space to store the specified number of elements.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Index<Element>.Count) {
        ensureCapacity(minimumCapacity)
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
        return unsafe elementStorage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + index).pointee)
        }
    }

    /// Iterates over all elements in the set.
    ///
    /// - Parameter body: A closure that receives each borrowed element.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        let count = elementStorage.count
        guard count > .zero else { return }
        _ = try unsafe elementStorage.withUnsafeMutablePointerToElements { (elements) throws(E) in
            for index in Index<Element>.zero..<count {
                try unsafe body((elements + index).pointee)
            }
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
        try elementStorage.withSpan(body)
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
        let count = elementStorage.count
        let countInt = Int(bitPattern: count)
        if countInt > 0 {
            let ptr = unsafe elementStorage.pointer(at: .zero)
            return try unsafe body(UnsafeBufferPointer<Element>(start: UnsafePointer(ptr.base), count: countInt))
        } else {
            let nilPtr: UnsafePointer<Element>? = nil
            return try unsafe body(UnsafeBufferPointer<Element>(start: nilPtr, count: 0))
        }
    }
}

// ============================================================================
// MARK: - Internal Identity (for testing)
// ============================================================================

extension Set.Ordered {
    @usableFromInline
    internal var _identity: ObjectIdentifier {
        ObjectIdentifier(elementStorage)
    }
}
