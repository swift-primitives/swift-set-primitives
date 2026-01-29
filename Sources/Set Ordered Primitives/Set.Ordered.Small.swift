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

// Note: Set.Ordered.Small is declared inside Set.Ordered (in Set.swift).
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
    public var count: Index<Element>.Count { Index<Element>.Count(Cardinal(UInt(storedCount))) }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { storedCount == 0 }

    /// The current capacity of the set.
    @inlinable
    public var capacity: Index<Element>.Count {
        if let heapStorage = heapStorage {
            return Index<Element>.Count(Cardinal(UInt(heapStorage.capacity)))
        }
        return Index<Element>.Count(Cardinal(UInt(inlineCapacity)))
    }
}

// MARK: - Pointer Helpers

extension Set_Primitives_Core.Set.Ordered.Small {
    /// Returns a pointer to the element at the given index in inline storage (for reading).
    @usableFromInline
    func inlineReadPointer(at index: Index<Element>) -> UnsafePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        let indexInt = Int(bitPattern: index.position.rawValue)
        return unsafe withUnsafePointer(to: inlineElements) { storagePtr in
            let basePtr = UnsafeRawPointer(storagePtr)
            return unsafe (basePtr + indexInt * stride).assumingMemoryBound(to: Element.self)
        }
    }
}

// MARK: - Hash Table Operations (Heap Mode)

extension Set_Primitives_Core.Set.Ordered.Small {
    /// Finds the position for an element with the given hash value (heap mode).
    @usableFromInline
    mutating func findHeapPosition(forHash hashValue: Int, equals: (Index<Element>) -> Bool) -> Index<Element>? {
        guard var hashTable = heapHashTable else { return nil }
        let result = hashTable.position(forHash: hashValue, equals: equals)
        heapHashTable = hashTable
        return result
    }

    /// Inserts a position into the hash table (heap mode).
    @usableFromInline
    mutating func insertHeapPosition(position: Index<Element>, hashValue: Int) {
        guard var hashTable = heapHashTable else { return }
        hashTable.insert(__unchecked: (), position: position, hashValue: hashValue)
        heapHashTable = hashTable
    }

    /// Removes a position from the hash table (heap mode).
    @usableFromInline
    mutating func removeHeapPosition(hashValue: Int, equals: (Index<Element>) -> Bool) -> Index<Element>? {
        guard var hashTable = heapHashTable else { return nil }
        let result = hashTable.remove(hashValue: hashValue, equals: equals)
        heapHashTable = hashTable
        return result
    }

    /// Updates positions after an element is removed from element storage (heap mode).
    @usableFromInline
    mutating func decrementHeapPositions(after removedPosition: Index<Element>) {
        guard var hashTable = heapHashTable else { return }
        hashTable.decrementPositions(after: removedPosition)
        heapHashTable = hashTable
    }

    /// Removes all entries from the hash table (heap mode).
    @usableFromInline
    mutating func clearHeapIndices(keepingCapacity: Bool) {
        guard var hashTable = heapHashTable else { return }
        hashTable.removeAll(keepingCapacity: keepingCapacity)
        if !keepingCapacity {
            heapHashTable = nil
        } else {
            heapHashTable = hashTable
        }
    }

    /// Spills inline storage to heap storage.
    @usableFromInline
    mutating func spillToHeap(minimumCapacity: Index<Element>.Count) {
        let minCapInt = Int(bitPattern: minimumCapacity)
        let newCapacity = Index<Element>.Count(Cardinal(UInt(Swift.max(minCapInt, inlineCapacity * 2))))
        let newStorage = Storage<Element>.create(minimumCapacity: newCapacity)
        var newHashTable = Hash.Table<Element>(minimumCapacity: newCapacity)

        // Copy elements from inline to heap
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafeMutablePointer(to: &inlineElements) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            unsafe newStorage.withUnsafeMutablePointerToElements { heapElements in
                for i in 0..<storedCount {
                    let inlinePtr = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                    unsafe (heapElements + i).initialize(to: inlinePtr.move())
                }
            }
        }
        newStorage.count = Index<Element>.Count(Cardinal(UInt(storedCount)))

        // Rebuild hash table
        for i in 0..<storedCount {
            _ = unsafe newStorage.withUnsafeMutablePointerToElements { elements in
                let elem = unsafe (elements + i).pointee
                let hashValue = elem.hashValue
                let position = Index<Element>(__unchecked: (), Ordinal(UInt(i)))
                newHashTable.insert(__unchecked: (), position: position, hashValue: hashValue)
            }
        }

        heapStorage = newStorage
        heapHashTable = newHashTable
    }
}

// MARK: - Core Operations (Copyable elements)

extension Set_Primitives_Core.Set.Ordered.Small where Element: Copyable {
    /// Returns the index of the given element, or `nil` if not present.
    @inlinable
    public mutating func index(_ element: Element) -> Index<Element>? {
        if heapHashTable != nil {
            // Heap mode: O(1) hash table lookup
            let storage = heapStorage!  // Capture to avoid overlapping access
            return findHeapPosition(
                forHash: element.hashValue,
                equals: { idx in
                    unsafe storage.withUnsafeMutablePointerToElements { elements in
                        unsafe elements[idx] == element
                    }
                }
            )
        } else {
            // Linear search in inline storage
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafePointer(to: inlineElements) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                for i in 0..<storedCount {
                    let elementPtr = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                    if unsafe elementPtr.pointee == element {
                        return Index<Element>(__unchecked: (), Ordinal(UInt(i)))
                    }
                }
                return nil
            }
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

        if heapStorage != nil {
            // Heap mode
            let heapCount = Int(bitPattern: heapStorage!.count)
            ensureHeapCapacity(Index<Element>.Count(Cardinal(UInt(heapCount + 1))))
            let index = Index<Element>(__unchecked: (), Ordinal(UInt(heapCount)))
            heapStorage!.initialize(to: element, at: index)
            heapStorage!.count = Index<Element>.Count(Cardinal(UInt(heapCount + 1)))

            // Insert position into hash table
            insertHeapPosition(position: index, hashValue: element.hashValue)

            storedCount += 1
            return (true, index)
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
            return (true, Index<Element>(__unchecked: (), Ordinal(UInt(idx))))
        } else {
            // Need to spill
            spillToHeap(minimumCapacity: Index<Element>.Count(Cardinal(UInt(storedCount + 1))))
            let index = Index<Element>(__unchecked: (), Ordinal(UInt(storedCount)))
            heapStorage!.initialize(to: element, at: index)
            heapStorage!.count = Index<Element>.Count(Cardinal(UInt(storedCount + 1)))

            // Insert position into hash table
            insertHeapPosition(position: index, hashValue: element.hashValue)

            storedCount += 1
            return (true, Index<Element>(__unchecked: (), Ordinal(UInt(storedCount - 1))))
        }
    }

    /// Removes an element from the set.
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        if heapStorage != nil {
            // Heap mode: use hash table for removal
            let hashValue = element.hashValue
            let storage = heapStorage!  // Capture to avoid overlapping access
            guard let removedPosition = removeHeapPosition(
                hashValue: hashValue,
                equals: { idx in
                    unsafe storage.withUnsafeMutablePointerToElements { elements in
                        unsafe elements[idx] == element
                    }
                }
            ) else {
                return nil
            }

            let heapCount = storage.count
            let removed = storage.move(at: removedPosition)
            shiftHeapLeft(removedAt: removedPosition, count: heapCount)

            // Update hash table positions after removal
            decrementHeapPositions(after: removedPosition)

            storedCount -= 1
            return removed
        } else {
            // Inline mode: linear search
            guard let idx = index(element) else {
                return nil
            }

            let idxInt = Int(bitPattern: idx.position.rawValue)
            let stride = MemoryLayout<Element>.stride
            let removed: Element = unsafe Swift.withUnsafeMutablePointer(to: &inlineElements) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + idxInt * stride).assumingMemoryBound(to: Element.self)
                let value = unsafe elementPtr.move()

                // Shift remaining elements left
                for i in idxInt..<(storedCount - 1) {
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
            heapStorage!.deinitialize()
            clearHeapIndices(keepingCapacity: keepingCapacity)
            if !keepingCapacity {
                heapStorage = nil
                heapHashTable = nil
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

    /// Shifts heap elements left after removal.
    @usableFromInline
    mutating func shiftHeapLeft(removedAt index: Index<Element>, count: Index<Element>.Count) {
        let indexInt = Int(bitPattern: index.position.rawValue)
        let countInt = Int(bitPattern: count)
        guard indexInt < countInt - 1 else {
            heapStorage!.count = Index<Element>.Count(Cardinal(UInt(countInt - 1)))
            return
        }
        _ = unsafe heapStorage!.withUnsafeMutablePointerToElements { elements in
            for i in indexInt..<(countInt - 1) {
                unsafe (elements + i).initialize(to: (elements + i + 1).move())
            }
        }
        heapStorage!.count = Index<Element>.Count(Cardinal(UInt(countInt - 1)))
    }
}

// MARK: - Capacity Management

extension Set_Primitives_Core.Set.Ordered.Small {
    @usableFromInline
    mutating func ensureHeapCapacity(_ minimumCapacity: Index<Element>.Count) {
        guard let currentHeap = heapStorage else { return }
        let currentCapacity = Index<Element>.Count(Cardinal(UInt(currentHeap.capacity)))
        guard currentCapacity < minimumCapacity else { return }

        let minCapInt = Int(bitPattern: minimumCapacity)
        let newCapacity = Index<Element>.Count(Cardinal(UInt(Swift.max(minCapInt, currentHeap.capacity * 2))))
        let newStorage = Storage<Element>.create(minimumCapacity: newCapacity)
        let currentCount = currentHeap.count
        currentHeap.move(to: newStorage, count: currentCount)
        newStorage.count = currentCount

        heapStorage = newStorage
    }
}

// MARK: - Element Access (Copyable only)

extension Set_Primitives_Core.Set.Ordered.Small where Element: Copyable {
    /// Accesses the element at the specified index.
    @inlinable
    public func element(at index: Index<Element>) -> Element? {
        guard index < count else {
            return nil
        }
        if let heapStorage = heapStorage {
            return unsafe heapStorage.withUnsafeMutablePointerToElements { elements in
                unsafe elements[index]
            }
        } else {
            return unsafe inlineReadPointer(at: index).pointee
        }
    }

    /// Subscript access to elements by index.
    @inlinable
    public subscript(index: Index<Element>) -> Element {
        precondition(index < count, "Index out of bounds")
        if let heapStorage = heapStorage {
            return unsafe heapStorage.withUnsafeMutablePointerToElements { elements in
                unsafe elements[index]
            }
        } else {
            return unsafe inlineReadPointer(at: index).pointee
        }
    }
}

// MARK: - First/Last Accessors (Copyable only)

extension Set_Primitives_Core.Set.Ordered.Small where Element: Copyable {
    /// The first element, or `nil` if the set is empty.
    @inlinable
    public var first: Element? {
        guard count > .zero else { return nil }
        if let heapStorage = heapStorage {
            return unsafe heapStorage.withUnsafeMutablePointerToElements { elements in
                unsafe elements[.zero]
            }
        } else {
            return unsafe inlineReadPointer(at: .zero).pointee
        }
    }

    /// The last element, or `nil` if the set is empty.
    @inlinable
    public var last: Element? {
        guard count > .zero else { return nil }
        let lastIndex = Index<Element>(__unchecked: (), Ordinal(count.rawValue.rawValue - 1))
        if let heapStorage = heapStorage {
            return unsafe heapStorage.withUnsafeMutablePointerToElements { elements in
                unsafe elements[lastIndex]
            }
        } else {
            return unsafe inlineReadPointer(at: lastIndex).pointee
        }
    }
}

// MARK: - Borrowed Element Access

extension Set_Primitives_Core.Set.Ordered.Small {
    /// Accesses the element at the given index via closure.
    @inlinable
    public func withElement<R>(at index: Index<Element>, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        if let heapStorage = heapStorage {
            return unsafe heapStorage.withUnsafeMutablePointerToElements { elements in
                body(unsafe (elements + index).pointee)
            }
        } else {
            return unsafe body(inlineReadPointer(at: index).pointee)
        }
    }

    /// Iterates over all elements in the set.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        guard count > .zero else { return }

        if let heapStorage = heapStorage {
            let heapResult: Result<Void, E> = unsafe heapStorage.withUnsafeMutablePointerToElements { elements in
                do throws(E) {
                    let count = self.count
                    try (.zero..<count).forEach { (index: Index<Element>) throws(E) in
                        try unsafe body((elements + index).pointee)
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
                    for i in 0..<storedCount {
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
            heapStorage.count = .zero
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

// Set.Ordered.Small is ~Copyable due to deinit and optional Hash.Table

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
        if count > .zero {
            if let heapStorage = heapStorage {
                let ptr = unsafe heapStorage.pointer(at: .zero)
                return try body(unsafe Span(_unsafeStart: UnsafePointer(ptr.base), count: Int(bitPattern: count)))
            } else {
                let result: Result<R, E> = unsafe withUnsafePointer(to: inlineElements) { storagePtr in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    let span = unsafe Span(_unsafeStart: elementPtr, count: Int(bitPattern: count))
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
            if let heapStorage = heapStorage {
                let ptr = unsafe heapStorage.pointer(at: .zero)
                var span = unsafe MutableSpan(_unsafeStart: ptr.base, count: elementCount)
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
        if count > .zero {
            if let heapStorage = heapStorage {
                let ptr = unsafe heapStorage.pointer(at: .zero)
                return try unsafe body(UnsafeBufferPointer(start: UnsafePointer(ptr.base), count: Int(bitPattern: count)))
            } else {
                return try unsafe withUnsafePointer(to: inlineElements) { (storagePtr) throws(E) -> R in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    return try unsafe body(UnsafeBufferPointer(start: elementPtr, count: Int(bitPattern: count)))
                }
            }
        } else {
            let nilPtr: UnsafePointer<Element>? = nil
            return try unsafe body(UnsafeBufferPointer(start: nilPtr, count: 0))
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
            if let heapStorage = heapStorage {
                let ptr = unsafe heapStorage.pointer(at: .zero)
                return try unsafe body(UnsafeMutableBufferPointer(start: ptr.base, count: elementCount))
            } else {
                return try unsafe withUnsafeMutablePointer(to: &inlineElements) { (storagePtr) throws(E) -> R in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                    return try unsafe body(UnsafeMutableBufferPointer(start: elementPtr, count: elementCount))
                }
            }
        } else {
            let nilPtr: UnsafeMutablePointer<Element>? = nil
            return try unsafe body(UnsafeMutableBufferPointer(start: nilPtr, count: 0))
        }
    }
}
