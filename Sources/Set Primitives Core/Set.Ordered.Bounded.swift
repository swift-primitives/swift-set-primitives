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

// Note: Set.Ordered.Bounded is declared inside Set.Ordered (in Set.Ordered.swift).
// This file contains only extensions to Set.Ordered.Bounded.

// MARK: - Properties

extension Set_Primitives_Core.Set.Ordered.Bounded {
    /// The number of elements in the set.
    @inlinable
    public var count: Int { elementStorage.header }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { elementStorage.header == 0 }

    /// Whether the set is at full capacity.
    @inlinable
    public var isFull: Bool { elementStorage.header >= capacity }
}

// MARK: - Storage Uniqueness

extension Set_Primitives_Core.Set.Ordered.Bounded {
    /// Ensures element storage is uniquely owned.
    ///
    /// Since `Set.Ordered.Bounded` is `~Copyable`, storage is always unique.
    /// This method exists for symmetry with other variants.
    @usableFromInline
    @inline(__always)
    mutating func makeUnique() {
        // No-op: ~Copyable struct always has unique storage
    }
}

// MARK: - Core Operations (Copyable elements)

extension Set_Primitives_Core.Set.Ordered.Bounded where Element: Copyable {
    /// Returns the index of the given element, or `nil` if not present.
    @inlinable
    public func index(_ element: Element) -> Int? {
        findPosition(
            forHash: element.hashValue,
            equals: { idx in elementStorage.readElement(at: idx) == element }
        )
    }

    /// Inserts an element into the set.
    ///
    /// - Parameter element: The element to insert.
    /// - Returns: A tuple indicating whether insertion occurred and the element's index.
    /// - Throws: ``Error/overflow`` if the set is full.
    @inlinable
    @discardableResult
    public mutating func insert(_ element: Element) throws(__SetOrderedBoundedError) -> (inserted: Bool, index: Int) {
        // Check for existing element
        if let existing = findPosition(
            forHash: element.hashValue,
            equals: { idx in elementStorage.readElement(at: idx) == element }
        ) {
            return (false, existing)
        }

        let index = elementStorage.header
        guard index < capacity else {
            throw .overflow(.init())
        }
        makeUnique()
        elementStorage.initializeElement(at: index, to: element)
        elementStorage.header = index + 1

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
        // Capture storage reference to avoid overlapping access
        let storage = elementStorage
        let hashValue = element.hashValue
        guard let removedPosition = removePosition(
            hashValue: hashValue,
            equals: { idx in storage.readElement(at: idx) == element }
        ) else {
            return nil
        }

        makeUnique()
        let count = elementStorage.header
        let removed = elementStorage.moveElement(at: removedPosition)
        elementStorage.shiftElementsLeftAndDecrement(removedAt: removedPosition, count: count)

        // Update hash table positions after removal
        decrementPositions(after: removedPosition)

        return removed
    }

    /// Returns whether the set contains the given element.
    @inlinable
    public func contains(_ element: Element) -> Bool {
        findPosition(
            forHash: element.hashValue,
            equals: { idx in elementStorage.readElement(at: idx) == element }
        ) != nil
    }

    /// Removes all elements from the set.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        makeUnique()
        elementStorage.deinitializeAllElements()
        clearIndices(keepingCapacity: keepingCapacity)
    }
}

// MARK: - Element Access (Copyable only)

extension Set_Primitives_Core.Set.Ordered.Bounded where Element: Copyable {
    /// Accesses the element at the specified index.
    @inlinable
    public func element(at index: Int) throws(__SetOrderedBoundedError) -> Element {
        guard index >= 0 && index < count else {
            throw .bounds(.init(index: index, count: count))
        }
        return elementStorage.readElement(at: index)
    }

    /// Subscript access to elements by index.
    @inlinable
    public subscript(index: Int) -> Element {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return elementStorage.readElement(at: index)
    }
}

// MARK: - First/Last Accessors (Copyable only)

extension Set_Primitives_Core.Set.Ordered.Bounded where Element: Copyable {
    /// The first element, or `nil` if the set is empty.
    @inlinable
    public var first: Element? {
        count > 0 ? elementStorage.readElement(at: 0) : nil
    }

    /// The last element, or `nil` if the set is empty.
    @inlinable
    public var last: Element? {
        count > 0 ? elementStorage.readElement(at: count - 1) : nil
    }
}

// MARK: - Borrowed Element Access

extension Set_Primitives_Core.Set.Ordered.Bounded {
    /// Accesses the element at the given index via closure.
    @inlinable
    public func withElement<R>(at index: Int, _ body: (borrowing Element) -> R) -> R {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return unsafe elementStorage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + index).pointee)
        }
    }

    /// Iterates over all elements in the set.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        let count = elementStorage.header
        guard count > 0 else { return }
        _ = try unsafe elementStorage.withUnsafeMutablePointerToElements { (elements) throws(E) in
            for i in 0..<count {
                try unsafe body((elements + i).pointee)
            }
        }
    }

    /// Removes and consumes all elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        let count = elementStorage.header
        guard count > 0 else { return }
        makeUnique()
        _ = unsafe elementStorage.withUnsafeMutablePointerToElements { elements in
            for i in 0..<count {
                unsafe body((elements + i).move())
            }
        }
        elementStorage.header = 0
        clearIndices(keepingCapacity: true)
    }
}

// MARK: - ~Copyable

// Set.Ordered.Bounded is ~Copyable due to containing IndexStorage

// MARK: - Span Access

extension Set_Primitives_Core.Set.Ordered.Bounded {
    /// Read-only span of the set's elements in insertion order.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the borrow of `self`.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - The returned span is lifetime-dependent; the compiler is expected to diagnose escapes.
    /// - Violating this contract is undefined behavior.
    @inlinable
    public var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            let count = elementStorage.header
            // cachedElementPtr from ManagedBuffer is always valid; pointer irrelevant when count == 0
            return unsafe Span(_unsafeStart: cachedElementPtr, count: count)
        }
    }

    /// Mutable span of the set's elements in insertion order.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the exclusive mutable borrow.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - The returned span is lifetime-dependent; the compiler is expected to diagnose escapes.
    /// - No concurrent mutable borrows are permitted.
    /// - No mutable + immutable borrow overlap is permitted.
    /// - Violating this contract is undefined behavior.
    ///
    /// ## Warning
    ///
    /// Modifying elements through this span may invalidate the hash table.
    /// Only use for in-place updates that preserve element identity/hash.
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            makeUnique()
            let count = elementStorage.header
            // cachedElementPtr from ManagedBuffer is always valid; pointer irrelevant when count == 0
            return unsafe MutableSpan(_unsafeStart: cachedElementPtr, count: count)
        }
    }
}

// MARK: - Buffer Access (Escape Hatch for C Interop)

@_spi(Unsafe)
extension Set_Primitives_Core.Set.Ordered.Bounded {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: Prefer `withSpan` for safe access.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let count = elementStorage.header
        if count > 0 {
            return try unsafe body(UnsafeBufferPointer(start: cachedElementPtr, count: count))
        } else {
            return try unsafe body(UnsafeBufferPointer(start: nil, count: 0))
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
        let count = elementStorage.header
        if count > 0 {
            return try unsafe body(UnsafeMutableBufferPointer(start: cachedElementPtr, count: count))
        } else {
            return try unsafe body(UnsafeMutableBufferPointer(start: nil, count: 0))
        }
    }
}

// MARK: - Hash.Protocol Conformance

// Note: Set.Ordered.Bounded conforms to Hash.Protocol (from hash-primitives) which supports
// ~Copyable types. Swift.Equatable and Swift.Hashable require Copyable and cannot
// be used with ~Copyable containers.

extension Set_Primitives_Core.Set.Ordered.Bounded: Hash.`Protocol` {
    /// Compares two bounded ordered sets for element-wise equality.
    @inlinable
    public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for i in 0..<lhs.count {
            let matches = lhs.elementStorage.withElement(at: i) { lhsElem in
                rhs.elementStorage.withElement(at: i) { rhsElem in
                    lhsElem == rhsElem
                }
            }
            if !matches {
                return false
            }
        }
        return true
    }

    /// Hashes the essential components of this set by feeding them into the given hasher.
    @inlinable
    public borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for i in 0..<count {
            // Use Hash.Protocol's hash(into:) directly instead of hasher.combine()
            // which requires Swift.Hashable
            elementStorage.withElement(at: i) { elem in
                elem.hash(into: &hasher)
            }
        }
    }
}
