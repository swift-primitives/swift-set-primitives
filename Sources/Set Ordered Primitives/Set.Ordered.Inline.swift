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

// Note: Set.Ordered.Static is declared inside Set.Ordered (in Set.swift).
// This file contains only extensions to Set.Ordered.Static.
//
// ## Design Note
//
// Inline sets use linear search for membership testing (O(n)).
// This is acceptable because:
// - Capacity is compile-time fixed and expected to be small
// - No heap allocation means no hash table overhead
// - For small n, linear search is often faster than hashing

// MARK: - Properties

extension Set_Primitives_Core.Set.Ordered.Static {
    /// The number of elements in the set.
    @inlinable
    public var count: Int { storedCount }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { storedCount == 0 }

    /// Whether the set is at full capacity.
    @inlinable
    public var isFull: Bool { count >= capacity }
}

// MARK: - Pointer Helpers

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Returns a pointer to the element at the given index (for reading).
    @usableFromInline
    func readPointerToElement(at index: Int) -> UnsafePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        return unsafe withUnsafePointer(to: elements) { storagePtr in
            let basePtr = UnsafeRawPointer(storagePtr)
            return unsafe (basePtr + index * stride).assumingMemoryBound(to: Element.self)
        }
    }

    /// Returns a mutable pointer to the element at the given index.
    @usableFromInline
    mutating func pointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
        let stride = MemoryLayout<Element>.stride
        return unsafe withUnsafeMutablePointer(to: &elements) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            return unsafe (basePtr + index * stride).assumingMemoryBound(to: Element.self)
        }
    }
}

// MARK: - Core Operations

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Returns the index of the given element, or `nil` if not present.
    ///
    /// - Complexity: O(n) linear search.
    @inlinable
    public func index(_ element: Element) -> Int? {
        for i in 0..<count {
            if unsafe readPointerToElement(at: i).pointee == element {
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
        guard count < capacity else {
            throw .overflow(.init())
        }
        let ptr = unsafe pointerToElement(at: storedCount)
        unsafe ptr.initialize(to: element)
        let idx = storedCount
        storedCount += 1
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
        let removed: Element = unsafe Swift.withUnsafeMutablePointer(to: &elements) { storagePtr in
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

    /// Removes all elements from the set.
    @inlinable
    public mutating func clear() {
        guard storedCount > 0 else { return }
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafeMutablePointer(to: &elements) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            for i in 0..<storedCount {
                let elementPtr = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                unsafe elementPtr.deinitialize(count: 1)
            }
        }
        storedCount = 0
    }
}

// MARK: - Element Access

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Accesses the element at the specified index.
    @inlinable
    public func element(at index: Int) throws(__SetOrderedInlineError) -> Element {
        guard index >= 0 && index < count else {
            throw .bounds(.init(index: index, count: count))
        }
        return unsafe readPointerToElement(at: index).pointee
    }

    /// Subscript access to elements by index.
    @inlinable
    public subscript(index: Int) -> Element {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return unsafe readPointerToElement(at: index).pointee
    }
}

// MARK: - First/Last Accessors

extension Set_Primitives_Core.Set.Ordered.Static {
    /// The first element, or `nil` if the set is empty.
    @inlinable
    public var first: Element? {
        count > 0 ? unsafe readPointerToElement(at: 0).pointee : nil
    }

    /// The last element, or `nil` if the set is empty.
    @inlinable
    public var last: Element? {
        count > 0 ? unsafe readPointerToElement(at: count - 1).pointee : nil
    }
}

// MARK: - Borrowed Element Access

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Accesses the element at the given index via closure.
    @inlinable
    public func withElement<R>(at index: Int, _ body: (borrowing Element) -> R) -> R {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return unsafe body(readPointerToElement(at: index).pointee)
    }

    /// Iterates over all elements in the set.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        let stride = MemoryLayout<Element>.stride
        let result: Result<Void, E> = unsafe withUnsafePointer(to: elements) { storagePtr in
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
        try result.get()
    }

    /// Removes and consumes all elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        guard storedCount > 0 else { return }
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafeMutablePointer(to: &elements) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            for i in 0..<storedCount {
                let elementPtr = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                unsafe body(elementPtr.move())
            }
        }
        storedCount = 0
    }
}

// MARK: - Span Access (Closure-Based)

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Safe, bounds-checked read access to contiguous storage via closure.
    ///
    /// Inline storage requires closure-based access because Span is ~Escapable
    /// and cannot be returned from property accessors without special compiler
    /// support. The closure ensures the Span cannot outlive `self`.
    ///
    /// - Parameter body: Closure receiving a Span view of the elements.
    /// - Returns: The result of the closure.
    /// - Complexity: O(1)
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        let result: Result<R, E> = unsafe withUnsafePointer(to: elements) { storagePtr in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            let span = unsafe Span(_unsafeStart: count > 0 ? elementPtr : UnsafePointer(bitPattern: 1)!, count: count)
            do throws(E) {
                return .success(try body(span))
            } catch {
                return .failure(error)
            }
        }
        return try result.get()
    }

    /// Safe, bounds-checked write access to contiguous storage via closure.
    ///
    /// Inline storage requires closure-based access because MutableSpan is
    /// ~Escapable and cannot be returned from property accessors without
    /// special compiler support.
    ///
    /// - Warning: Modifying elements may create duplicates if the
    ///   modifications affect element equality/hash.
    /// - Parameter body: Closure receiving a MutableSpan view of the elements.
    /// - Returns: The result of the closure.
    /// - Complexity: O(1)
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (inout MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        let elementCount = storedCount
        let result: Result<R, E> = unsafe withUnsafeMutablePointer(to: &elements) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            var span = unsafe MutableSpan(_unsafeStart: elementCount > 0 ? elementPtr : UnsafeMutablePointer(bitPattern: 1)!, count: elementCount)
            do throws(E) {
                return .success(try body(&span))
            } catch {
                return .failure(error)
            }
        }
        return try result.get()
    }
}

// MARK: - Buffer Access (Escape Hatch for C Interop)

@_spi(Unsafe)
extension Set_Primitives_Core.Set.Ordered.Static {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: Prefer ``span`` for safe access.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let result: Result<R, E> = unsafe withUnsafePointer(to: elements) { storagePtr in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            do throws(E) {
                return .success(try unsafe body(UnsafeBufferPointer(start: count > 0 ? elementPtr : nil, count: count)))
            } catch {
                return .failure(error)
            }
        }
        return try result.get()
    }

    /// Provides mutable access to the underlying contiguous storage.
    ///
    /// - Warning: Prefer ``mutableSpan`` for safe access.
    /// - Warning: Modifying elements may create duplicates.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let elementCount = storedCount
        let result: Result<R, E> = unsafe withUnsafeMutablePointer(to: &elements) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            do throws(E) {
                return .success(try unsafe body(UnsafeMutableBufferPointer(start: elementCount > 0 ? elementPtr : nil, count: elementCount)))
            } catch {
                return .failure(error)
            }
        }
        return try result.get()
    }
}
