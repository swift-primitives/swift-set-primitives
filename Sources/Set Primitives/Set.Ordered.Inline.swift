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

// Note: Set.Ordered.Inline is declared inside Set.Ordered (in Set.Ordered.swift).
// This file contains only extensions to Set.Ordered.Inline.
//
// ## Design Note
//
// Inline sets use linear search for membership testing (O(n)).
// This is acceptable because:
// - Capacity is compile-time fixed and expected to be small
// - No heap allocation means no hash table overhead
// - For small n, linear search is often faster than hashing

// MARK: - Properties

extension Set_Primitives.Set.Ordered.Inline {
    /// The number of elements in the set.
    @inlinable
    public var count: Int { _count }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Whether the set is at full capacity.
    @inlinable
    public var isFull: Bool { _count >= capacity }
}

// MARK: - Core Operations

extension Set_Primitives.Set.Ordered.Inline {
    /// Returns the index of the given element, or `nil` if not present.
    ///
    /// - Complexity: O(n) linear search.
    @inlinable
    public func index(_ element: Element) -> Int? {
        for i in 0..<_count {
            if unsafe _readPointerToElement(at: i).pointee == element {
                return i
            }
        }
        return nil
    }

    /// Returns whether the set contains the given element.
    ///
    /// - Complexity: O(n) linear search.
    @inlinable
    public func contains(_ element: Element) -> Bool {
        index(element) != nil
    }

    /// Inserts an element into the set.
    ///
    /// - Parameter element: The element to insert.
    /// - Returns: A tuple indicating whether insertion occurred and the element's index.
    /// - Throws: ``Error/overflow`` if the set is full.
    /// - Complexity: O(n) for membership check.
    @inlinable
    @discardableResult
    public mutating func insert(_ element: Element) throws(__SetOrderedInlineError) -> (inserted: Bool, index: Int) {
        if let existing = index(element) {
            return (false, existing)
        }
        guard _count < capacity else {
            throw .overflow
        }
        let ptr = unsafe _pointerToElement(at: _count)
        unsafe ptr.initialize(to: element)
        let idx = _count
        _count += 1
        return (true, idx)
    }

    /// Removes an element from the set.
    ///
    /// - Parameter element: The element to remove.
    /// - Returns: The removed element, or `nil` if not present.
    /// - Complexity: O(n) for search and shift.
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        guard let idx = index(element) else {
            return nil
        }
        let stride = MemoryLayout<Element>.stride
        let removed: Element = unsafe Swift.withUnsafeMutablePointer(to: &_elements) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe (basePtr + idx * stride).assumingMemoryBound(to: Element.self)
            let value = unsafe elementPtr.move()

            // Shift remaining elements left
            for i in idx..<(_count - 1) {
                let src = unsafe (basePtr + (i + 1) * stride).assumingMemoryBound(to: Element.self)
                let dst = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                unsafe dst.initialize(to: src.move())
            }
            return value
        }
        _count -= 1
        return removed
    }

    /// Removes all elements from the set.
    @inlinable
    public mutating func clear() {
        guard _count > 0 else { return }
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafeMutablePointer(to: &_elements) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            for i in 0..<_count {
                let elementPtr = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                unsafe elementPtr.deinitialize(count: 1)
            }
        }
        _count = 0
    }
}

// MARK: - Element Access

extension Set_Primitives.Set.Ordered.Inline {
    /// Accesses the element at the specified index.
    @inlinable
    public func element(at index: Int) throws(__SetOrderedInlineError) -> Element {
        guard index >= 0 && index < _count else {
            throw .indexOutOfBounds(index: index, count: _count)
        }
        return unsafe _readPointerToElement(at: index).pointee
    }

    /// Subscript access to elements by index.
    @inlinable
    public subscript(index: Int) -> Element {
        precondition(index >= 0 && index < _count, "Index out of bounds")
        return unsafe _readPointerToElement(at: index).pointee
    }
}

// MARK: - First/Last Accessors

extension Set_Primitives.Set.Ordered.Inline {
    /// The first element, or `nil` if the set is empty.
    @inlinable
    public var first: Element? {
        _count > 0 ? unsafe _readPointerToElement(at: 0).pointee : nil
    }

    /// The last element, or `nil` if the set is empty.
    @inlinable
    public var last: Element? {
        _count > 0 ? unsafe _readPointerToElement(at: _count - 1).pointee : nil
    }
}

// MARK: - Borrowed Element Access

extension Set_Primitives.Set.Ordered.Inline {
    /// Accesses the element at the given index via closure.
    @inlinable
    public func withElement<R>(at index: Int, _ body: (borrowing Element) -> R) -> R {
        precondition(index >= 0 && index < _count, "Index out of bounds")
        return unsafe body(_readPointerToElement(at: index).pointee)
    }

    /// Iterates over all elements in the set.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        let stride = MemoryLayout<Element>.stride
        let result: Result<Void, E> = unsafe withUnsafePointer(to: _elements) { storagePtr in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            do throws(E) {
                for i in 0..<_count {
                    let elementPtr = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                    try unsafe body(elementPtr.pointee)
                }
                return .success(())
            } catch {
                return .failure(error)
            }
        }
        try result.get()
    }

    /// Removes and consumes all elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        guard _count > 0 else { return }
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafeMutablePointer(to: &_elements) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            for i in 0..<_count {
                let elementPtr = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                unsafe body(elementPtr.move())
            }
        }
        _count = 0
    }
}

// MARK: - Span Access

extension Set_Primitives.Set.Ordered.Inline {
    /// Provides read-only span access to the set's elements in insertion order.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the closure.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - Violating this contract is undefined behavior.
    ///
    /// ## Note
    ///
    /// Inline storage requires closure-based access because the storage address
    /// is not stable (it moves with the struct). Use `span` property on heap-backed
    /// variants (Ordered, Bounded) for direct access.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe withUnsafePointer(to: _elements) { storagePtr throws(E) -> R in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            let span = unsafe Span(_unsafeStart: elementPtr, count: _count)
            return try body(span)
        }
    }

    /// Provides mutable span access to the set's elements in insertion order.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the closure.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - No concurrent mutable borrows are permitted.
    /// - Violating this contract is undefined behavior.
    ///
    /// ## Warning
    ///
    /// Modifying elements through this span may create duplicates if the
    /// modifications affect element equality/hash.
    ///
    /// ## Note
    ///
    /// Inline storage requires closure-based access because the storage address
    /// is not stable (it moves with the struct). Use `mutableSpan` property on
    /// heap-backed variants (Ordered, Bounded) for direct access.
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (borrowing MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe withUnsafeMutablePointer(to: &_elements) { storagePtr throws(E) -> R in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            let span = unsafe MutableSpan(_unsafeStart: elementPtr, count: _count)
            return try body(span)
        }
    }
}

// MARK: - Buffer Access (Escape Hatch for C Interop)

@_spi(Unsafe)
extension Set_Primitives.Set.Ordered.Inline {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: Prefer `withSpan` for safe access.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let result: Result<R, E> = unsafe withUnsafePointer(to: _elements) { storagePtr in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            do throws(E) {
                return .success(try unsafe body(UnsafeBufferPointer(start: _count > 0 ? elementPtr : nil, count: _count)))
            } catch {
                return .failure(error)
            }
        }
        return try result.get()
    }

    /// Provides mutable access to the underlying contiguous storage.
    ///
    /// - Warning: Prefer `withMutableSpan` for safe access.
    /// - Warning: Modifying elements may create duplicates.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let result: Result<R, E> = unsafe withUnsafeMutablePointer(to: &_elements) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            do throws(E) {
                return .success(try unsafe body(UnsafeMutableBufferPointer(start: _count > 0 ? elementPtr : nil, count: _count)))
            } catch {
                return .failure(error)
            }
        }
        return try result.get()
    }
}
