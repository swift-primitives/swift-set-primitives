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
// MARK: - Initialization (Copyable)
// ============================================================================

extension Set.Ordered {
    /// Creates an ordered set with reserved capacity.
    @inlinable
    public init(reservingCapacity capacity: Index<Element>.Count) throws(__SetOrderedError) {
        self.init()
        if capacity > .zero {
            self.reserve(capacity)
        }
    }
}

extension Set.Ordered where Element: Copyable {
    /// Creates an ordered set containing the elements of a sequence.
    @inlinable
    public init<S: Swift.Sequence>(_ elements: S) where S.Element == Element {
        self.init()
        for element in elements {
            insert(element)
        }
    }
}

// ============================================================================
// MARK: - Storage Uniqueness (CoW)
// ============================================================================

extension Set.Ordered where Element: Copyable {
    /// Ensures element storage is uniquely owned (copy-on-write).
    @usableFromInline
    @inline(__always)
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&elementStorage) {
            elementStorage = elementStorage.copy()
            hashTable = copyHashTable()
        }
    }
}

// ============================================================================
// MARK: - Hash Table Copy Helper
// ============================================================================

extension Set.Ordered where Element: Copyable {
    /// Copies the hash table by re-inserting all elements.
    ///
    /// Used for CoW when the element storage is copied.
    @usableFromInline
    func copyHashTable() -> Hash.Table<Element> {
        var new = Hash.Table<Element>(minimumCapacity: count)
        for index in .zero..<count {
            let hash = unsafe elementStorage.withUnsafeMutablePointerToElements { elements in
                unsafe elements[index].hashValue
            }
            new.insert(__unchecked: (), position: index, hashValue: hash)
        }
        return new
    }
}

// ============================================================================
// MARK: - Core Operations (Copyable - with CoW)
// ============================================================================

extension Set.Ordered where Element: Copyable {
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

    /// Inserts an element into the set (CoW-aware).
    @inlinable
    @discardableResult
    public mutating func insert(_ element: Element) -> (inserted: Bool, index: Index<Element>) {
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

        makeUnique()
        let index = Index<Element>(elementStorage.count)
        let newCount = elementStorage.count + .one
        ensureCapacity(newCount)
        elementStorage.initialize(to: element, at: index)
        elementStorage.count = newCount

        insertPosition(position: index, hashValue: element.hashValue)

        return (true, index)
    }

    /// Removes an element from the set (CoW-aware).
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        makeUnique()

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

        let currentCount = elementStorage.count
        let removed = elementStorage.move(at: removedPosition)
        shiftLeft(removedAt: removedPosition, count: currentCount)

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

    /// Removes all elements from the set (CoW-aware).
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        makeUnique()
        elementStorage.deinitialize()
        clearIndices(keepingCapacity: keepingCapacity)
        if !keepingCapacity {
            elementStorage = Storage<Element>.create(minimumCapacity: .zero)
        }
    }

    /// Shifts elements left after removal.
    @usableFromInline
    mutating func shiftLeft(removedAt index: Index<Element>, count: Index<Element>.Count) {
        let indexInt = Int(bitPattern: index.position)
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

// ============================================================================
// MARK: - Element Access (Copyable - returns copies)
// ============================================================================

extension Set.Ordered where Element: Copyable {
    /// Accesses the element at the specified index.
    @inlinable
    public func element(at index: Index<Element>) throws(__SetOrderedError) -> Element {
        guard index < count else {
            throw .bounds(.init(index: Int(bitPattern: index.position), count: Int(bitPattern: count)))
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

// ============================================================================
// MARK: - First/Last Accessors (Copyable)
// ============================================================================

extension Set.Ordered where Element: Copyable {
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

// ============================================================================
// MARK: - Drain (Copyable)
// ============================================================================

extension Set.Ordered where Element: Copyable {
    /// Removes and consumes all elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        let count = elementStorage.count
        guard count > .zero else { return }
        makeUnique()
        _ = unsafe elementStorage.withUnsafeMutablePointerToElements { elements in
            (.zero..<count).forEach { index in
                unsafe body((elements + index).move())
            }
        }
        elementStorage.count = .zero
        clearIndices(keepingCapacity: true)
    }
}

// ============================================================================
// MARK: - Mutable Span (Copyable - with CoW)
// ============================================================================

extension Set.Ordered where Element: Copyable {
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

// ============================================================================
// MARK: - Buffer Access (Copyable)
// ============================================================================

@_spi(Unsafe)
extension Set.Ordered where Element: Copyable {
    /// Provides mutable access to the underlying contiguous storage.
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

// ============================================================================
// MARK: - Hash.Protocol Conformance
// ============================================================================

extension Set.Ordered: Hash.`Protocol` {
    /// Compares two ordered sets for element-wise equality.
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

    /// Hashes the essential components of this set.
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

// ============================================================================
// MARK: - Description (Copyable)
// ============================================================================

#if !hasFeature(Embedded)
extension Set.Ordered where Element: Copyable {
    /// A textual representation of the set.
    public var description: String {
        var result = "Set.Ordered(["
        var first = true
        let count = elementStorage.count
        _ = unsafe elementStorage.withUnsafeMutablePointerToElements { elements in
            (.zero..<count).forEach { index in
                if !first { result += ", " }
                result += String(describing: unsafe elements[index])
                first = false
            }
        }
        result += "])"
        return result
    }
}
#endif
