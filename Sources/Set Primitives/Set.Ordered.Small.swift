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

// Note: Set.Ordered.Small is declared inside Set.Ordered (in Set.Ordered.swift).
// This file contains only extensions to Set.Ordered.Small.
//
// ## Design Note
//
// Small sets use inline storage until capacity is exceeded, then spill to heap.
// - Inline mode: linear search O(n) for membership (no hash table overhead)
// - Heap mode: O(1) hash table lookup

// MARK: - Properties

extension Set_Primitives.Set.Ordered.Small {
    /// The number of elements in the set.
    @inlinable
    public var count: Int { _count }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// The current capacity of the set.
    @inlinable
    public var capacity: Int {
        if let heapStorage = _heapStorage {
            return heapStorage.capacity
        }
        return inlineCapacity
    }
}

// MARK: - Core Operations

extension Set_Primitives.Set.Ordered.Small {
    /// Returns the index of the given element, or `nil` if not present.
    @inlinable
    public func index(_ element: Element) -> Int? {
        if let heapIndices = _heapIndices {
            return heapIndices[element]
        } else {
            // Linear search in inline storage
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafePointer(to: _inlineElements) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                for i in 0..<_count {
                    let elementPtr = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                    if unsafe elementPtr.pointee == element {
                        return i
                    }
                }
                return nil
            }
        }
    }

    /// Returns whether the set contains the given element.
    @inlinable
    public func contains(_ element: Element) -> Bool {
        index(element) != nil
    }

    /// Inserts an element into the set.
    ///
    /// If inline storage is full, spills to heap automatically.
    @inlinable
    @discardableResult
    public mutating func insert(_ element: Element) -> (inserted: Bool, index: Int) {
        if let existing = index(element) {
            return (false, existing)
        }

        if _heapStorage != nil {
            // Heap mode
            let count = _heapStorage!.header
            _ensureHeapCapacity(count + 1)
            _heapStorage!._initializeElement(at: count, to: element)
            _heapStorage!.header = count + 1
            _heapIndices![element] = count
            _count += 1
            return (true, count)
        } else if _count < inlineCapacity {
            // Inline mode with room
            let stride = MemoryLayout<Element>.stride
            let idx = _count
            unsafe Swift.withUnsafeMutablePointer(to: &_inlineElements) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + idx * stride).assumingMemoryBound(to: Element.self)
                unsafe elementPtr.initialize(to: element)
            }
            _count += 1
            return (true, idx)
        } else {
            // Need to spill
            _spillToHeap(minimumCapacity: _count + 1)
            _heapStorage!._initializeElement(at: _count, to: element)
            _heapStorage!.header = _count + 1
            _heapIndices![element] = _count
            _count += 1
            return (true, _count - 1)
        }
    }

    /// Removes an element from the set.
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        guard let idx = index(element) else {
            return nil
        }

        if _heapStorage != nil {
            // Heap mode
            _heapIndices!.removeValue(forKey: element)
            let count = _heapStorage!.header
            let removed = _heapStorage!._moveElement(at: idx)
            _heapStorage!._shiftElementsLeftAndDecrement(removedAt: idx, count: count)

            // Update indices for shifted elements
            for i in idx..<(count - 1) {
                let shiftedElement = _heapStorage!._readElement(at: i)
                _heapIndices![shiftedElement] = i
            }

            _count -= 1
            return removed
        } else {
            // Inline mode
            let stride = MemoryLayout<Element>.stride
            let removed: Element = unsafe Swift.withUnsafeMutablePointer(to: &_inlineElements) { storagePtr in
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
    }

    /// Removes all elements from the set.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        guard _count > 0 else { return }

        if _heapStorage != nil {
            _heapStorage!._deinitializeAllElements()
            _heapIndices!.removeAll(keepingCapacity: keepingCapacity)
            if !keepingCapacity {
                _heapStorage = nil
                _heapIndices = nil
                unsafe (_heapElementPtr = nil)
            }
        } else {
            let stride = MemoryLayout<Element>.stride
            unsafe Swift.withUnsafeMutablePointer(to: &_inlineElements) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                for i in 0..<_count {
                    let elementPtr = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                }
            }
        }
        _count = 0
    }
}

// MARK: - Capacity Management

extension Set_Primitives.Set.Ordered.Small {
    @usableFromInline
    mutating func _ensureHeapCapacity(_ minimumCapacity: Int) {
        guard let heapStorage = _heapStorage else { return }
        guard heapStorage.capacity < minimumCapacity else { return }

        let newCapacity = Swift.max(minimumCapacity, heapStorage.capacity * 2)
        let newStorage = Set_Primitives.Set<Element>.Ordered.ElementStorage.create(minimumCapacity: newCapacity)
        heapStorage._moveAllElements(to: newStorage)
        newStorage.header = heapStorage.header

        _heapStorage = newStorage
        unsafe (_heapElementPtr = newStorage._elementsPointer)
    }
}

// MARK: - Element Access

extension Set_Primitives.Set.Ordered.Small {
    /// Accesses the element at the specified index.
    @inlinable
    public func element(at index: Int) -> Element? {
        guard index >= 0 && index < _count else {
            return nil
        }
        if let heapStorage = _heapStorage {
            return heapStorage._readElement(at: index)
        } else {
            return unsafe _inlineReadPointerToElement(at: index).pointee
        }
    }

    /// Subscript access to elements by index.
    @inlinable
    public subscript(index: Int) -> Element {
        precondition(index >= 0 && index < _count, "Index out of bounds")
        if let heapStorage = _heapStorage {
            return heapStorage._readElement(at: index)
        } else {
            return unsafe _inlineReadPointerToElement(at: index).pointee
        }
    }
}

// MARK: - First/Last Accessors

extension Set_Primitives.Set.Ordered.Small {
    /// The first element, or `nil` if the set is empty.
    @inlinable
    public var first: Element? {
        guard _count > 0 else { return nil }
        if let heapStorage = _heapStorage {
            return heapStorage._readElement(at: 0)
        } else {
            return unsafe _inlineReadPointerToElement(at: 0).pointee
        }
    }

    /// The last element, or `nil` if the set is empty.
    @inlinable
    public var last: Element? {
        guard _count > 0 else { return nil }
        if let heapStorage = _heapStorage {
            return heapStorage._readElement(at: _count - 1)
        } else {
            return unsafe _inlineReadPointerToElement(at: _count - 1).pointee
        }
    }
}

// MARK: - Borrowed Element Access

extension Set_Primitives.Set.Ordered.Small {
    /// Accesses the element at the given index via closure.
    @inlinable
    public func withElement<R>(at index: Int, _ body: (borrowing Element) -> R) -> R {
        precondition(index >= 0 && index < _count, "Index out of bounds")
        if let heapStorage = _heapStorage {
            return unsafe heapStorage.withUnsafeMutablePointerToElements { elements in
                body(unsafe (elements + index).pointee)
            }
        } else {
            return unsafe body(_inlineReadPointerToElement(at: index).pointee)
        }
    }

    /// Iterates over all elements in the set.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        guard _count > 0 else { return }

        if let heapStorage = _heapStorage {
            let heapResult: Result<Void, E> = unsafe heapStorage.withUnsafeMutablePointerToElements { elements in
                do throws(E) {
                    for i in 0..<_count {
                        try unsafe body((elements + i).pointee)
                    }
                    return .success(())
                } catch {
                    return .failure(error)
                }
            }
            try heapResult.get()
        } else {
            let stride = MemoryLayout<Element>.stride
            let inlineResult: Result<Void, E> = unsafe withUnsafePointer(to: _inlineElements) { storagePtr in
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
            try inlineResult.get()
        }
    }

    /// Removes and consumes all elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        guard _count > 0 else { return }

        if let heapStorage = _heapStorage {
            _ = unsafe heapStorage.withUnsafeMutablePointerToElements { elements in
                for i in 0..<_count {
                    unsafe body((elements + i).move())
                }
            }
            _heapStorage!.header = 0
            _heapIndices!.removeAll(keepingCapacity: true)
        } else {
            let stride = MemoryLayout<Element>.stride
            unsafe Swift.withUnsafeMutablePointer(to: &_inlineElements) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                for i in 0..<_count {
                    let elementPtr = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                    unsafe body(elementPtr.move())
                }
            }
        }
        _count = 0
    }
}

// MARK: - Span Access

extension Set_Primitives.Set.Ordered.Small {
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
    /// Small sets use closure-based access because inline storage address
    /// is not stable (it moves with the struct). Use `span` property on
    /// heap-only variants (Ordered, Bounded) for direct access.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        if _count > 0 {
            if let heapPtr = unsafe _heapElementPtr {
                let span = unsafe Span(_unsafeStart: heapPtr, count: _count)
                return try body(span)
            } else {
                return try unsafe withUnsafePointer(to: _inlineElements) { storagePtr throws(E) -> R in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    let span = unsafe Span(_unsafeStart: elementPtr, count: _count)
                    return try body(span)
                }
            }
        } else {
            // Empty: pointer irrelevant when count == 0
            let span = unsafe Span(_unsafeStart: UnsafePointer<Element>(bitPattern: 1)!, count: 0)
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
    /// Modifying elements through this span may invalidate uniqueness if the
    /// modifications affect element equality/hash.
    ///
    /// ## Note
    ///
    /// Small sets use closure-based access because inline storage address
    /// is not stable (it moves with the struct). Use `mutableSpan` property on
    /// heap-only variants (Ordered, Bounded) for direct access.
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (borrowing MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        if _count > 0 {
            if let heapPtr = unsafe _heapElementPtr {
                let span = unsafe MutableSpan(_unsafeStart: heapPtr, count: _count)
                return try body(span)
            } else {
                return try unsafe withUnsafeMutablePointer(to: &_inlineElements) { storagePtr throws(E) -> R in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    let span = unsafe MutableSpan(_unsafeStart: elementPtr, count: _count)
                    return try body(span)
                }
            }
        } else {
            // Empty: pointer irrelevant when count == 0
            let span = unsafe MutableSpan(_unsafeStart: UnsafeMutablePointer<Element>(bitPattern: 1)!, count: 0)
            return try body(span)
        }
    }
}

// MARK: - Buffer Access (Escape Hatch for C Interop)

@_spi(Unsafe)
extension Set_Primitives.Set.Ordered.Small {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: Prefer `withSpan` for safe access.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        if _count > 0 {
            if let heapPtr = unsafe _heapElementPtr {
                return try unsafe body(UnsafeBufferPointer(start: heapPtr, count: _count))
            } else {
                return try unsafe withUnsafePointer(to: _inlineElements) { (storagePtr) throws(E) -> R in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    return try unsafe body(UnsafeBufferPointer(start: elementPtr, count: _count))
                }
            }
        } else {
            return try unsafe body(UnsafeBufferPointer(start: nil, count: 0))
        }
    }

    /// Provides mutable access to the underlying contiguous storage.
    ///
    /// - Warning: Prefer `withMutableSpan` for safe access.
    /// - Warning: Modifying elements may invalidate uniqueness.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        if _count > 0 {
            if let heapPtr = unsafe _heapElementPtr {
                return try unsafe body(UnsafeMutableBufferPointer(start: heapPtr, count: _count))
            } else {
                return try unsafe withUnsafeMutablePointer(to: &_inlineElements) { (storagePtr) throws(E) -> R in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    return try unsafe body(UnsafeMutableBufferPointer(start: elementPtr, count: _count))
                }
            }
        } else {
            return try unsafe body(UnsafeMutableBufferPointer(start: nil, count: 0))
        }
    }
}
