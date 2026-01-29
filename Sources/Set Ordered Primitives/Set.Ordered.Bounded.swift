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

// Note: Set.Ordered.Fixed is declared inside Set.Ordered (in Set.swift).
// This file contains only extensions to Set.Ordered.Fixed.

// MARK: - Properties

extension Set_Primitives_Core.Set.Ordered.Fixed {
    /// The number of elements in the set.
    @inlinable
    public var count: Index<Element>.Count { elementStorage.count }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { elementStorage.count == .zero }

    /// Whether the set is at full capacity.
    @inlinable
    public var isFull: Bool { elementStorage.count >= maximumCapacity }

    /// The maximum capacity (alias for API consistency).
    @inlinable
    public var capacity: Index<Element>.Count { maximumCapacity }
}

// MARK: - Storage Uniqueness

extension Set_Primitives_Core.Set.Ordered.Fixed {
    /// Ensures element storage is uniquely owned.
    ///
    /// Since `Set.Ordered.Fixed` is `~Copyable`, storage is always unique.
    /// This method exists for symmetry with other variants.
    @usableFromInline
    @inline(__always)
    mutating func makeUnique() {
        // No-op: ~Copyable struct always has unique storage
    }
}

// MARK: - Hash Table Operations

extension Set_Primitives_Core.Set.Ordered.Fixed {
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

// MARK: - Core Operations (Copyable elements)

extension Set_Primitives_Core.Set.Ordered.Fixed where Element: Copyable {
    /// Returns the index of the given element, or `nil` if not present.
    @inlinable
    public func index(_ element: Element) -> Index<Element>? {
        findPosition(
            forHash: element.hashValue,
            equals: { idx in
                unsafe elementStorage.withUnsafeMutablePointerToElements { elements in
                    unsafe elements[idx] == element
                }
            }
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
        // Check for existing element
        if let existing = findPosition(
            forHash: element.hashValue,
            equals: { idx in
                unsafe elementStorage.withUnsafeMutablePointerToElements { elements in
                    unsafe elements[idx] == element
                }
            }
        ) {
            return (false, existing)
        }

        let currentCount = elementStorage.count
        guard currentCount < maximumCapacity else {
            throw .overflow(.init())
        }
        makeUnique()
        let index = Index<Element>(__unchecked: (), Ordinal(currentCount.rawValue.rawValue))
        elementStorage.initialize(to: element, at: index)
        elementStorage.count = Index<Element>.Count(Cardinal(currentCount.rawValue.rawValue + 1))

        // Insert position into hash table
        insertPosition(position: index, hashValue: element.hashValue)

        return (true, index)
    }

    /// Removes an element from the set.
    ///
    /// - Parameter element: The element to remove.
    /// - Returns: The removed element, or `nil` if not present.
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        let hashValue = element.hashValue
        let storage = elementStorage  // Capture reference to avoid overlapping access
        guard let removedPosition = removePosition(
            hashValue: hashValue,
            equals: { idx in
                unsafe storage.withUnsafeMutablePointerToElements { elements in
                    unsafe elements[idx] == element
                }
            }
        ) else {
            return nil
        }

        makeUnique()
        let currentCount = elementStorage.count
        let removed = elementStorage.move(at: removedPosition)
        shiftLeft(removedAt: removedPosition, count: currentCount)

        // Update hash table positions after removal
        decrementPositions(after: removedPosition)

        return removed
    }

    /// Returns whether the set contains the given element.
    @inlinable
    public func contains(_ element: Element) -> Bool {
        findPosition(
            forHash: element.hashValue,
            equals: { idx in
                unsafe elementStorage.withUnsafeMutablePointerToElements { elements in
                    unsafe elements[idx] == element
                }
            }
        ) != nil
    }

    /// Removes all elements from the set.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        makeUnique()
        elementStorage.deinitialize()
        clearIndices(keepingCapacity: keepingCapacity)
    }

    /// Shifts elements left after removal.
    @usableFromInline
    mutating func shiftLeft(removedAt index: Index<Element>, count: Index<Element>.Count) {
        let indexInt = Int(bitPattern: index.position.rawValue)
        let countInt = Int(bitPattern: count)
        guard indexInt < countInt - 1 else {
            elementStorage.count = Index<Element>.Count(Cardinal(UInt(countInt - 1)))
            return
        }
        _ = unsafe elementStorage.withUnsafeMutablePointerToElements { elements in
            for i in indexInt..<(countInt - 1) {
                unsafe (elements + i).initialize(to: (elements + i + 1).move())
            }
        }
        elementStorage.count = Index<Element>.Count(Cardinal(UInt(countInt - 1)))
    }
}

// MARK: - Element Access (Copyable only)

extension Set_Primitives_Core.Set.Ordered.Fixed where Element: Copyable {
    /// Accesses the element at the specified index.
    @inlinable
    public func element(at index: Index<Element>) throws(__SetOrderedFixedError) -> Element {
        guard index < count else {
            throw .bounds(.init(index: Int(bitPattern: index.position.rawValue), count: Int(bitPattern: count)))
        }
        return unsafe elementStorage.withUnsafeMutablePointerToElements { elements in
            unsafe elements[index]
        }
    }

    /// Subscript access to elements by index.
    @inlinable
    public subscript(index: Index<Element>) -> Element {
        precondition(index < count, "Index out of bounds")
        return unsafe elementStorage.withUnsafeMutablePointerToElements { elements in
            unsafe elements[index]
        }
    }
}

// MARK: - First/Last Accessors (Copyable only)

extension Set_Primitives_Core.Set.Ordered.Fixed where Element: Copyable {
    /// The first element, or `nil` if the set is empty.
    @inlinable
    public var first: Element? {
        count > .zero ? unsafe elementStorage.withUnsafeMutablePointerToElements { unsafe $0[.zero] } : nil
    }

    /// The last element, or `nil` if the set is empty.
    @inlinable
    public var last: Element? {
        guard count > .zero else { return nil }
        let lastIndex = Index<Element>(__unchecked: (), Ordinal(count.rawValue.rawValue - 1))
        return unsafe elementStorage.withUnsafeMutablePointerToElements { unsafe $0[lastIndex] }
    }
}

// MARK: - Borrowed Element Access

extension Set_Primitives_Core.Set.Ordered.Fixed {
    /// Accesses the element at the given index via closure.
    @inlinable
    public func withElement<R>(at index: Index<Element>, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return unsafe elementStorage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + index).pointee)
        }
    }

    /// Iterates over all elements in the set.
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

    /// Removes and consumes all elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        let count = elementStorage.count
        guard count > .zero else { return }
        makeUnique()
        _ = unsafe elementStorage.withUnsafeMutablePointerToElements { elements in
            for index in Index<Element>.zero..<count {
                unsafe body((elements + index).move())
            }
        }
        elementStorage.count = .zero
        clearIndices(keepingCapacity: true)
    }
}

// MARK: - ~Copyable

// Set.Ordered.Fixed is ~Copyable due to containing Hash.Table

// MARK: - Span Access

extension Set_Primitives_Core.Set.Ordered.Fixed {
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

    /// Provides mutable span access to the set's elements in insertion order.
    ///
    /// - Warning: Modifying elements through this span may invalidate the hash table.
    ///   Only use for in-place updates that preserve element identity/hash.
    ///
    /// - Parameter body: A closure that receives the mutable span.
    /// - Returns: The value returned by the closure.
    /// - Throws: Rethrows any error thrown by the closure.
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (inout MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        makeUnique()
        let count = elementStorage.count
        var thrown: E? = nil
        let result: R? = unsafe elementStorage.withUnsafeMutablePointerToElements { base in
            var span = unsafe MutableSpan(_unsafeStart: base, count: Int(bitPattern: count))
            do {
                return try body(&span)
            } catch let e as E {
                thrown = e
                return nil
            } catch {
                preconditionFailure("unexpected error type")
            }
        }
        if let thrown { throw thrown }
        return result!
    }
}

// MARK: - Buffer Access (Escape Hatch for C Interop)

@_spi(Unsafe)
extension Set_Primitives_Core.Set.Ordered.Fixed {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: Prefer `withSpan` for safe access.
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

    /// Provides mutable access to the underlying contiguous storage.
    ///
    /// - Warning: Prefer `withMutableSpan` for safe access.
    /// - Warning: Modifying elements may invalidate the hash table.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        makeUnique()
        let count = elementStorage.count
        let countInt = Int(bitPattern: count)
        if countInt > 0 {
            let ptr = unsafe elementStorage.pointer(at: .zero)
            return try unsafe body(UnsafeMutableBufferPointer<Element>(start: ptr.base, count: countInt))
        } else {
            let nilPtr: UnsafeMutablePointer<Element>? = nil
            return try unsafe body(UnsafeMutableBufferPointer<Element>(start: nilPtr, count: 0))
        }
    }
}

// MARK: - Hash.Protocol Conformance

// Note: Set.Ordered.Fixed conforms to Hash.Protocol (from hash-primitives) which supports
// ~Copyable types. Swift.Equatable and Swift.Hashable require Copyable and cannot
// be used with ~Copyable containers.

extension Set_Primitives_Core.Set.Ordered.Fixed: Hash.`Protocol` {
    /// Compares two Fixed ordered sets for element-wise equality.
    @inlinable
    public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        let count = lhs.count
        guard count > .zero else { return true }
        return unsafe lhs.elementStorage.withUnsafeMutablePointerToElements { lhsElements in
            unsafe rhs.elementStorage.withUnsafeMutablePointerToElements { rhsElements in
                var matches = true
                for index in Index<Element>.zero..<count {
                    if unsafe lhsElements[index] != rhsElements[index] {
                        matches = false
                    }
                }
                return matches
            }
        }
    }

    /// Hashes the essential components of this set by feeding them into the given hasher.
    @inlinable
    public borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(Int(bitPattern: count))
        let count = elementStorage.count
        guard count > .zero else { return }
        _ = unsafe elementStorage.withUnsafeMutablePointerToElements { elements in
            for index in Index<Element>.zero..<count {
                unsafe elements[index].hash(into: &hasher)
            }
        }
    }
}
