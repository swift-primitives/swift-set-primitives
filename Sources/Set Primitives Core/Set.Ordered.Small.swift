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

extension Set_Primitives_Core.Set.Ordered.Small {
    /// The number of elements in the set.
    @inlinable
    public var count: Int { storedCount }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { storedCount == 0 }

    /// The current capacity of the set.
    @inlinable
    public var capacity: Int {
        if let heapStorage = heapStorage {
            return heapStorage.capacity
        }
        return inlineCapacity
    }
}

// MARK: - Core Operations (Copyable elements)

extension Set_Primitives_Core.Set.Ordered.Small where Element: Copyable {
    /// Returns the index of the given element, or `nil` if not present.
    @inlinable
    public func index(_ element: Element) -> Int? {
        if heapIndexStorage != nil {
            // Heap mode: O(1) hash table lookup
            return findHeapPosition(
                forHash: element.hashValue,
                equals: { idx in heapStorage!.readElement(at: idx) == element }
            )
        } else {
            // Linear search in inline storage
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafePointer(to: inlineElements) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                for i in 0..<count {
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

        if heapStorage != nil {
            // Heap mode
            let heapCount = heapStorage!.header
            ensureHeapCapacity(heapCount + 1)
            heapStorage!.initializeElement(at: heapCount, to: element)
            heapStorage!.header = heapCount + 1

            // Insert position into hash table
            insertHeapPosition(position: heapCount, hashValue: element.hashValue)

            storedCount += 1
            return (true, heapCount)
        } else if storedCount < inlineCapacity {
            // Inline mode with room
            let stride = MemoryLayout<Element>.stride
            let idx = storedCount
            unsafe Swift.withUnsafeMutablePointer(to: &inlineElements) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + idx * stride).assumingMemoryBound(to: Element.self)
                unsafe elementPtr.initialize(to: element)
            }
            storedCount += 1
            return (true, idx)
        } else {
            // Need to spill
            spillToHeap(minimumCapacity: storedCount + 1)
            heapStorage!.initializeElement(at: storedCount, to: element)
            heapStorage!.header = storedCount + 1

            // Insert position into hash table
            insertHeapPosition(position: storedCount, hashValue: element.hashValue)

            storedCount += 1
            return (true, storedCount - 1)
        }
    }

    /// Removes an element from the set.
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        if let storage = heapStorage {
            // Heap mode: use hash table for removal
            // Capture storage reference to avoid overlapping access
            let hashValue = element.hashValue
            guard let removedPosition = removeHeapPosition(
                hashValue: hashValue,
                equals: { idx in storage.readElement(at: idx) == element }
            ) else {
                return nil
            }

            let heapCount = heapStorage!.header
            let removed = heapStorage!.moveElement(at: removedPosition)
            heapStorage!.shiftElementsLeftAndDecrement(removedAt: removedPosition, count: heapCount)

            // Update hash table positions after removal
            decrementHeapPositions(after: removedPosition)

            storedCount -= 1
            return removed
        } else {
            // Inline mode: linear search
            guard let idx = index(element) else {
                return nil
            }

            let stride = MemoryLayout<Element>.stride
            let removed: Element = unsafe Swift.withUnsafeMutablePointer(to: &inlineElements) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + idx * stride).assumingMemoryBound(to: Element.self)
                let value = unsafe elementPtr.move()

                // Shift remaining elements left
                for i in idx..<(storedCount - 1) {
                    let src = unsafe (basePtr + (i + 1) * stride).assumingMemoryBound(to: Element.self)
                    let dst = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                    unsafe dst.initialize(to: src.move())
                }
                return value
            }
            storedCount -= 1
            return removed
        }
    }

    /// Removes all elements from the set.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        guard storedCount > 0 else { return }

        if heapStorage != nil {
            heapStorage!.deinitializeAllElements()
            clearHeapIndices(keepingCapacity: keepingCapacity)
            if !keepingCapacity {
                heapStorage = nil
                heapIndexStorage = nil
                unsafe (heapElementPtr = nil)
            }
        } else {
            let stride = MemoryLayout<Element>.stride
            unsafe Swift.withUnsafeMutablePointer(to: &inlineElements) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                for i in 0..<storedCount {
                    let elementPtr = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                }
            }
        }
        storedCount = 0
    }
}

// MARK: - Capacity Management

extension Set_Primitives_Core.Set.Ordered.Small {
    @usableFromInline
    mutating func ensureHeapCapacity(_ minimumCapacity: Int) {
        guard let currentHeap = heapStorage else { return }
        guard currentHeap.capacity < minimumCapacity else { return }

        let newCapacity = Swift.max(minimumCapacity, currentHeap.capacity * 2)
        let newStorage = Set_Primitives_Core.Set<Element>.Ordered.ElementStorage.create(minimumCapacity: newCapacity)
        currentHeap.moveAllElements(to: newStorage)
        newStorage.header = currentHeap.header

        heapStorage = newStorage
        unsafe (heapElementPtr = newStorage.elementsPointer)
    }
}

// MARK: - Element Access (Copyable only)

extension Set_Primitives_Core.Set.Ordered.Small where Element: Copyable {
    /// Accesses the element at the specified index.
    @inlinable
    public func element(at index: Int) -> Element? {
        guard index >= 0 && index < count else {
            return nil
        }
        if let heapStorage = heapStorage {
            return heapStorage.readElement(at: index)
        } else {
            return unsafe inlineReadPointerToElement(at: index).pointee
        }
    }

    /// Subscript access to elements by index.
    @inlinable
    public subscript(index: Int) -> Element {
        precondition(index >= 0 && index < count, "Index out of bounds")
        if let heapStorage = heapStorage {
            return heapStorage.readElement(at: index)
        } else {
            return unsafe inlineReadPointerToElement(at: index).pointee
        }
    }
}

// MARK: - First/Last Accessors (Copyable only)

extension Set_Primitives_Core.Set.Ordered.Small where Element: Copyable {
    /// The first element, or `nil` if the set is empty.
    @inlinable
    public var first: Element? {
        guard count > 0 else { return nil }
        if let heapStorage = heapStorage {
            return heapStorage.readElement(at: 0)
        } else {
            return unsafe inlineReadPointerToElement(at: 0).pointee
        }
    }

    /// The last element, or `nil` if the set is empty.
    @inlinable
    public var last: Element? {
        guard count > 0 else { return nil }
        if let heapStorage = heapStorage {
            return heapStorage.readElement(at: count - 1)
        } else {
            return unsafe inlineReadPointerToElement(at: count - 1).pointee
        }
    }
}

// MARK: - Borrowed Element Access

extension Set_Primitives_Core.Set.Ordered.Small {
    /// Accesses the element at the given index via closure.
    @inlinable
    public func withElement<R>(at index: Int, _ body: (borrowing Element) -> R) -> R {
        precondition(index >= 0 && index < count, "Index out of bounds")
        if let heapStorage = heapStorage {
            return unsafe heapStorage.withUnsafeMutablePointerToElements { elements in
                body(unsafe (elements + index).pointee)
            }
        } else {
            return unsafe body(inlineReadPointerToElement(at: index).pointee)
        }
    }

    /// Iterates over all elements in the set.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        guard count > 0 else { return }

        if let heapStorage = heapStorage {
            let heapResult: Result<Void, E> = unsafe heapStorage.withUnsafeMutablePointerToElements { elements in
                do throws(E) {
                    for i in 0..<count {
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
            let inlineResult: Result<Void, E> = unsafe withUnsafePointer(to: inlineElements) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                do throws(E) {
                    for i in 0..<count {
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
        guard storedCount > 0 else { return }

        if let heapStorage = heapStorage {
            _ = unsafe heapStorage.withUnsafeMutablePointerToElements { elements in
                for i in 0..<storedCount {
                    unsafe body((elements + i).move())
                }
            }
            heapStorage.header = 0
            clearHeapIndices(keepingCapacity: true)
        } else {
            let stride = MemoryLayout<Element>.stride
            unsafe Swift.withUnsafeMutablePointer(to: &inlineElements) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                for i in 0..<storedCount {
                    let elementPtr = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                    unsafe body(elementPtr.move())
                }
            }
        }
        storedCount = 0
    }
}

// MARK: - ~Copyable

// Set.Ordered.Small is ~Copyable due to deinit and optional IndexStorage

// MARK: - Span Access (Closure-Based)

extension Set_Primitives_Core.Set.Ordered.Small {
    /// Safe, bounds-checked read access to contiguous storage via closure.
    ///
    /// Small sets use closure-based access because inline storage mode requires
    /// it (Span is ~Escapable and cannot be returned from property accessors
    /// without special compiler support).
    ///
    /// - Parameter body: Closure receiving a Span view of the elements.
    /// - Returns: The result of the closure.
    /// - Complexity: O(1)
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        if count > 0 {
            if let heapPtr = unsafe heapElementPtr {
                return try body(unsafe Span(_unsafeStart: heapPtr, count: count))
            } else {
                let result: Result<R, E> = unsafe withUnsafePointer(to: inlineElements) { storagePtr in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    let span = unsafe Span(_unsafeStart: elementPtr, count: count)
                    do throws(E) {
                        return .success(try body(span))
                    } catch {
                        return .failure(error)
                    }
                }
                return try result.get()
            }
        } else {
            return try body(unsafe Span(_unsafeStart: UnsafePointer(bitPattern: 1)!, count: 0))
        }
    }

    /// Safe, bounds-checked write access to contiguous storage via closure.
    ///
    /// Small sets use closure-based access because inline storage mode requires
    /// it (MutableSpan is ~Escapable and cannot be returned from property
    /// accessors without special compiler support).
    ///
    /// - Warning: Modifying elements may invalidate uniqueness if the
    ///   modifications affect element equality/hash.
    /// - Parameter body: Closure receiving a MutableSpan view of the elements.
    /// - Returns: The result of the closure.
    /// - Complexity: O(1)
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (inout MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        let elementCount = storedCount
        if elementCount > 0 {
            if let heapPtr = unsafe heapElementPtr {
                var span = unsafe MutableSpan(_unsafeStart: heapPtr, count: elementCount)
                return try body(&span)
            } else {
                let result: Result<R, E> = unsafe withUnsafeMutablePointer(to: &inlineElements) { storagePtr in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    var span = unsafe MutableSpan(_unsafeStart: elementPtr, count: elementCount)
                    do throws(E) {
                        return .success(try body(&span))
                    } catch {
                        return .failure(error)
                    }
                }
                return try result.get()
            }
        } else {
            var span = unsafe MutableSpan(_unsafeStart: UnsafeMutablePointer<Element>(bitPattern: 1)!, count: 0)
            return try body(&span)
        }
    }
}

// MARK: - Buffer Access (Escape Hatch for C Interop)

@_spi(Unsafe)
extension Set_Primitives_Core.Set.Ordered.Small {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: Prefer ``span`` for safe access.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        if count > 0 {
            if let heapPtr = unsafe heapElementPtr {
                return try unsafe body(UnsafeBufferPointer(start: heapPtr, count: count))
            } else {
                return try unsafe withUnsafePointer(to: inlineElements) { (storagePtr) throws(E) -> R in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    return try unsafe body(UnsafeBufferPointer(start: elementPtr, count: count))
                }
            }
        } else {
            return try unsafe body(UnsafeBufferPointer(start: nil, count: 0))
        }
    }

    /// Provides mutable access to the underlying contiguous storage.
    ///
    /// - Warning: Prefer ``mutableSpan`` for safe access.
    /// - Warning: Modifying elements may invalidate uniqueness.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let elementCount = storedCount
        if elementCount > 0 {
            if let heapPtr = unsafe heapElementPtr {
                return try unsafe body(UnsafeMutableBufferPointer(start: heapPtr, count: elementCount))
            } else {
                return try unsafe withUnsafeMutablePointer(to: &inlineElements) { (storagePtr) throws(E) -> R in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    return try unsafe body(UnsafeMutableBufferPointer(start: elementPtr, count: elementCount))
                }
            }
        } else {
            return try unsafe body(UnsafeMutableBufferPointer(start: nil, count: 0))
        }
    }
}
