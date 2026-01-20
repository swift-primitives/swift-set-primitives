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

extension Set_Primitives.Set.Ordered.Bounded {
    /// The number of elements in the set.
    @inlinable
    public var count: Int { _elementStorage.header }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { _elementStorage.header == 0 }

    /// Whether the set is at full capacity.
    @inlinable
    public var isFull: Bool { _elementStorage.header >= capacity }
}

// MARK: - Copy-on-Write

extension Set_Primitives.Set.Ordered.Bounded {
    @usableFromInline
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_elementStorage) {
            _elementStorage = _elementStorage.copy()
            unsafe (_cachedElementPtr = _elementStorage._elementsPointer)
        }
    }
}

// MARK: - Core Operations

extension Set_Primitives.Set.Ordered.Bounded {
    /// Returns the index of the given element, or `nil` if not present.
    @inlinable
    public func index(_ element: Element) -> Int? {
        _indices[element]
    }

    /// Inserts an element into the set.
    ///
    /// - Parameter element: The element to insert.
    /// - Returns: A tuple indicating whether insertion occurred and the element's index.
    /// - Throws: ``Error/overflow`` if the set is full.
    @inlinable
    @discardableResult
    public mutating func insert(_ element: Element) throws(__SetOrderedBoundedError) -> (inserted: Bool, index: Int) {
        if let existing = _indices[element] {
            return (false, existing)
        }
        let index = _elementStorage.header
        guard index < capacity else {
            throw .overflow
        }
        makeUnique()
        _elementStorage._initializeElement(at: index, to: element)
        _elementStorage.header = index + 1
        _indices[element] = index
        return (true, index)
    }

    /// Removes an element from the set.
    ///
    /// - Parameter element: The element to remove.
    /// - Returns: The removed element, or `nil` if not present.
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        guard let index = _indices.removeValue(forKey: element) else {
            return nil
        }
        makeUnique()
        let count = _elementStorage.header
        let removed = _elementStorage._moveElement(at: index)
        _elementStorage._shiftElementsLeftAndDecrement(removedAt: index, count: count)

        // Update indices for shifted elements
        for i in index..<(count - 1) {
            let shiftedElement = _elementStorage._readElement(at: i)
            _indices[shiftedElement] = i
        }

        return removed
    }

    /// Returns whether the set contains the given element.
    @inlinable
    public func contains(_ element: Element) -> Bool {
        _indices[element] != nil
    }

    /// Removes all elements from the set.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        makeUnique()
        _elementStorage._deinitializeAllElements()
        _indices.removeAll(keepingCapacity: keepingCapacity)
    }
}

// MARK: - Element Access

extension Set_Primitives.Set.Ordered.Bounded {
    /// Accesses the element at the specified index.
    @inlinable
    public func element(at index: Int) throws(__SetOrderedBoundedError) -> Element {
        guard index >= 0 && index < count else {
            throw .bounds(index: index, count: count)
        }
        return _elementStorage._readElement(at: index)
    }

    /// Subscript access to elements by index.
    @inlinable
    public subscript(index: Int) -> Element {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return _elementStorage._readElement(at: index)
    }
}

// MARK: - First/Last Accessors

extension Set_Primitives.Set.Ordered.Bounded {
    /// The first element, or `nil` if the set is empty.
    @inlinable
    public var first: Element? {
        count > 0 ? _elementStorage._readElement(at: 0) : nil
    }

    /// The last element, or `nil` if the set is empty.
    @inlinable
    public var last: Element? {
        count > 0 ? _elementStorage._readElement(at: count - 1) : nil
    }
}

// MARK: - Borrowed Element Access

extension Set_Primitives.Set.Ordered.Bounded {
    /// Accesses the element at the given index via closure.
    @inlinable
    public func withElement<R>(at index: Int, _ body: (borrowing Element) -> R) -> R {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return unsafe _elementStorage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + index).pointee)
        }
    }

    /// Iterates over all elements in the set.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        let count = _elementStorage.header
        guard count > 0 else { return }
        _ = try unsafe _elementStorage.withUnsafeMutablePointerToElements { (elements) throws(E) in
            for i in 0..<count {
                try unsafe body((elements + i).pointee)
            }
        }
    }

    /// Removes and consumes all elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        let count = _elementStorage.header
        guard count > 0 else { return }
        makeUnique()
        _ = unsafe _elementStorage.withUnsafeMutablePointerToElements { elements in
            for i in 0..<count {
                unsafe body((elements + i).move())
            }
        }
        _elementStorage.header = 0
        _indices.removeAll(keepingCapacity: true)
    }
}

// MARK: - Span Access

extension Set_Primitives.Set.Ordered.Bounded {
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
            let count = _elementStorage.header
            // _cachedElementPtr from ManagedBuffer is always valid; pointer irrelevant when count == 0
            return unsafe Span(_unsafeStart: _cachedElementPtr, count: count)
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
            let count = _elementStorage.header
            // _cachedElementPtr from ManagedBuffer is always valid; pointer irrelevant when count == 0
            return unsafe MutableSpan(_unsafeStart: _cachedElementPtr, count: count)
        }
    }
}

// MARK: - Buffer Access (Escape Hatch for C Interop)

@_spi(Unsafe)
extension Set_Primitives.Set.Ordered.Bounded {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: Prefer `withSpan` for safe access.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let count = _elementStorage.header
        if count > 0 {
            return try unsafe body(UnsafeBufferPointer(start: _cachedElementPtr, count: count))
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
        let count = _elementStorage.header
        if count > 0 {
            return try unsafe body(UnsafeMutableBufferPointer(start: _cachedElementPtr, count: count))
        } else {
            return try unsafe body(UnsafeMutableBufferPointer(start: nil, count: 0))
        }
    }
}

// MARK: - Equatable

extension Set_Primitives.Set.Ordered.Bounded: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for i in 0..<lhs.count {
            if lhs._elementStorage._readElement(at: i) != rhs._elementStorage._readElement(at: i) {
                return false
            }
        }
        return true
    }
}

// MARK: - Hashable

extension Set_Primitives.Set.Ordered.Bounded: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for i in 0..<count {
            hasher.combine(_elementStorage._readElement(at: i))
        }
    }
}
