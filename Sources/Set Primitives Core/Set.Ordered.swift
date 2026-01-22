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

// ===----------------------------------------------------------------------===//
// MARK: - Semantic Invariants
// ===----------------------------------------------------------------------===//
//
// ## Canonical Ordering
//
// Elements are stored in insertion order.
//
// - The element storage is the source of truth for ordering
// - Index `i` always refers to the i-th inserted element
// - The hash table maps elements to their indices for O(1) lookup
//
// ## Ordering Semantics
//
// - Insertion appends to end if the element is new
// - Removal shifts subsequent elements (indices change)
// - Re-insertion of a removed element adds to the end
//
// ## What Must Never Happen
//
// - Element storage and hash table must never be inconsistent
// - Duplicate elements must never exist
// - Element storage must never contain uninitialized memory within `0..<count`
//
// ## Key Constraint
//
// - Elements are always Copyable (Hashable implies Copyable)
// - The container itself supports ~Copyable for storage in move-only contexts
//
// ===----------------------------------------------------------------------===//

extension Set_Primitives_Core.Set {
    /// An ordered set that preserves insertion order with O(1) membership testing.
    ///
    /// `Ordered` combines the uniqueness guarantees of a set with the ordering
    /// semantics of an array. Elements are stored in insertion order and can be
    /// accessed by index.
    ///
    /// ## API
    ///
    /// Core operations use single-token names:
    ///
    /// ```swift
    /// var set = Set<String>.Ordered()
    ///
    /// // Insert
    /// set.insert("apple")
    /// set.insert("banana")
    ///
    /// // Membership
    /// if set.contains("apple") { ... }
    ///
    /// // Index lookup
    /// if let idx = set.index("apple") { ... }
    ///
    /// // Remove
    /// set.remove("banana")
    /// ```
    ///
    /// Set algebra uses nested accessors:
    ///
    /// ```swift
    /// let union = a.algebra.union(b)
    /// let intersection = a.algebra.intersection(b)
    /// let difference = a.algebra.subtract(b)
    /// let symmetric = a.algebra.symmetric.difference(b)
    /// ```
    ///
    /// ## Ordering Semantics
    ///
    /// - Insertion adds to the end if the element is new
    /// - Removal shifts subsequent elements (indices change)
    /// - Re-insertion of a removed element adds to the end
    ///
    /// ## Copy-on-Write
    ///
    /// `Set.Ordered` uses copy-on-write semantics: copies share storage until mutation.
    ///
    /// ## Thread Safety
    ///
    /// Not thread-safe for concurrent mutation. Synchronize externally.
    ///
    /// ## Complexity
    ///
    /// - Insert/remove/contains: O(1) average (O(n) for remove due to shifting)
    /// - Index lookup: O(1) average
    /// - Random access by index: O(1)
    ///
    /// ## Variants
    ///
    /// - ``Set/Ordered``: Dynamically-growing storage (this type)
    /// - ``Set/Ordered/Bounded``: Fixed-capacity, throws on overflow
    /// - ``Set/Ordered/Inline``: Zero-allocation inline storage with compile-time capacity
    /// - ``Set/Ordered/Small``: Inline storage with automatic spill to heap
    @safe
    public struct Ordered {

        // MARK: - ElementStorage (nested to support future ~Copyable container)

        /// Internal storage class for elements using ManagedBuffer.
        @usableFromInline
        final class ElementStorage: ManagedBuffer<Int, Element> {

            /// Creates empty storage with the specified minimum capacity.
            @usableFromInline
            static func create(minimumCapacity: Int) -> ElementStorage {
                let storage = ElementStorage.create(minimumCapacity: minimumCapacity) { _ in 0 }
                return unsafe unsafeDowncast(storage, to: ElementStorage.self)
            }

            deinit {
                let count = header
                guard count > 0 else { return }
                _ = unsafe withUnsafeMutablePointerToElements { elements in
                    for i in 0..<count {
                        unsafe (elements + i).deinitialize(count: 1)
                    }
                }
            }

            /// Returns pointer to element storage.
            @usableFromInline
            var _elementsPointer: UnsafeMutablePointer<Element> {
                unsafe withUnsafeMutablePointerToElements { unsafe $0 }
            }

            /// Initializes element at the given index.
            @usableFromInline
            func _initializeElement(at index: Int, to element: Element) {
                let ptr = unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
                unsafe ptr.initialize(to: element)
            }

            /// Reads element at the given index.
            @usableFromInline
            func _readElement(at index: Int) -> Element {
                unsafe withUnsafeMutablePointerToElements { elements in
                    unsafe elements[index]
                }
            }

            /// Moves element from the given index.
            @usableFromInline
            func _moveElement(at index: Int) -> Element {
                unsafe withUnsafeMutablePointerToElements { elements in
                    unsafe (elements + index).move()
                }
            }

            /// Shifts elements left from `from` to fill gap at removed index.
            @usableFromInline
            func _shiftElementsLeftAndDecrement(removedAt index: Int, count: Int) {
                guard index < count - 1 else {
                    header = count - 1
                    return
                }
                _ = unsafe withUnsafeMutablePointerToElements { elements in
                    for i in index..<(count - 1) {
                        unsafe (elements + i).initialize(to: (elements + i + 1).move())
                    }
                }
                header = count - 1
            }

            /// Moves all elements to new storage.
            @usableFromInline
            func _moveAllElements(to newStorage: ElementStorage) {
                let count = header
                guard count > 0 else { return }
                _ = unsafe withUnsafeMutablePointerToElements { src in
                    unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                        for i in 0..<count {
                            unsafe (dst + i).initialize(to: (src + i).move())
                        }
                    }
                }
            }

            /// Copies all elements to new storage.
            @usableFromInline
            func _copyAllElements(to newStorage: ElementStorage) {
                let count = header
                guard count > 0 else { return }
                _ = unsafe withUnsafeMutablePointerToElements { src in
                    unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                        for i in 0..<count {
                            unsafe (dst + i).initialize(to: src[i])
                        }
                    }
                }
            }

            /// Creates a copy of this storage.
            @usableFromInline
            func copy() -> ElementStorage {
                let count = header
                guard count > 0 else {
                    return ElementStorage.create(minimumCapacity: 0)
                }

                let new = ElementStorage.create(minimumCapacity: capacity)
                new.header = count
                _copyAllElements(to: new)
                return new
            }

            /// Deinitializes all elements.
            @usableFromInline
            func _deinitializeAllElements() {
                let count = header
                guard count > 0 else { return }
                _ = unsafe withUnsafeMutablePointerToElements { elements in
                    for i in 0..<count {
                        unsafe (elements + i).deinitialize(count: 1)
                    }
                }
                header = 0
            }

            /// Deinitializes elements in a range.
            ///
            /// Used by consuming iterator to clean up remaining elements.
            @usableFromInline
            func _deinitializeElements(from startIndex: Int, count: Int) {
                guard count > 0 else { return }
                _ = unsafe withUnsafeMutablePointerToElements { elements in
                    for i in startIndex..<(startIndex + count) {
                        unsafe (elements + i).deinitialize(count: 1)
                    }
                }
            }
        }

        @usableFromInline
        var _elementStorage: ElementStorage

        /// Hash table mapping elements to indices for O(1) lookup.
        @usableFromInline
        var _indices: Hash.Table<Element>

        /// Cached pointer to element storage.
        @usableFromInline
        var _cachedElementPtr: UnsafeMutablePointer<Element>

        /// Creates an empty ordered set.
        @inlinable
        public init() {
            self._elementStorage = ElementStorage.create(minimumCapacity: 0)
            self._indices = Hash.Table()
            unsafe (self._cachedElementPtr = _elementStorage._elementsPointer)
        }

        // MARK: - Bounded Variant

        /// A fixed-capacity ordered set that throws on overflow.
        ///
        /// `Set.Ordered.Bounded` allocates storage upfront and throws when
        /// inserting an element would exceed the capacity.
        @safe
        public struct Bounded {
            @usableFromInline
            var _elementStorage: ElementStorage

            @usableFromInline
            var _indices: Hash.Table<Element>

            @usableFromInline
            var _cachedElementPtr: UnsafeMutablePointer<Element>

            /// The maximum number of elements the set can hold.
            public let capacity: Int

            /// Creates a bounded ordered set with the specified capacity.
            @inlinable
            public init(capacity: Int) throws(__SetOrderedBoundedError) {
                guard capacity >= 0 else {
                    throw .invalidCapacity
                }
                self._elementStorage = ElementStorage.create(minimumCapacity: capacity)
                self._indices = Hash.Table(minimumCapacity: capacity)
                unsafe (self._cachedElementPtr = _elementStorage._elementsPointer)
                self.capacity = capacity
            }
        }

        // MARK: - Inline Variant

        /// A fixed-capacity, inline-storage ordered set with compile-time capacity.
        ///
        /// `Set.Ordered.Inline` stores elements directly within the struct's memory layout,
        /// requiring no heap allocation.
        public struct Inline<let capacity: Int>: ~Copyable {
            /// Maximum element stride supported by inline storage (64 bytes per slot).
            @usableFromInline
            static var _maxElementStride: Int { 64 }

            /// Raw byte storage for elements.
            @usableFromInline
            var _elements: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

            /// Current element count.
            @usableFromInline
            var _count: Int

            /// Creates an empty inline ordered set.
            @inlinable
            public init() {
                precondition(
                    MemoryLayout<Element>.stride <= Self._maxElementStride,
                    "Element stride exceeds inline storage slot size"
                )
                self._elements = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
                self._count = 0
            }

            deinit {
                let count = _count
                guard count > 0 else { return }

                let stride = MemoryLayout<Element>.stride
                unsafe Swift.withUnsafeBytes(of: _elements) { bytes in
                    let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for i in 0..<count {
                        let elementPtr = unsafe (basePtr + i * stride)
                            .assumingMemoryBound(to: Element.self)
                        unsafe elementPtr.deinitialize(count: 1)
                    }
                }
            }

            @usableFromInline
            @unsafe
            mutating func _pointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
                let stride = MemoryLayout<Element>.stride
                return unsafe Swift.withUnsafeMutablePointer(to: &_elements) { storagePtr in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe (basePtr + index * stride)
                        .assumingMemoryBound(to: Element.self)
                    return unsafe elementPtr
                }
            }

            @usableFromInline
            @unsafe
            func _readPointerToElement(at index: Int) -> UnsafePointer<Element> {
                let stride = MemoryLayout<Element>.stride
                return unsafe Swift.withUnsafePointer(to: _elements) { storagePtr in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe (basePtr + index * stride)
                        .assumingMemoryBound(to: Element.self)
                    return unsafe elementPtr
                }
            }
        }

        // MARK: - Small Variant

        /// An ordered set with small-buffer optimization (SmallVec pattern).
        @safe
        public struct Small<let inlineCapacity: Int>: ~Copyable {
            @usableFromInline
            static var _maxElementStride: Int { 64 }

            @usableFromInline
            var _inlineElements: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

            @usableFromInline
            var _count: Int

            @usableFromInline
            var _heapStorage: ElementStorage?

            @usableFromInline
            var _heapIndices: Hash.Table<Element>?

            @usableFromInline
            var _heapElementPtr: UnsafeMutablePointer<Element>?

            @inlinable
            public init() {
                precondition(
                    MemoryLayout<Element>.stride <= Self._maxElementStride,
                    "Element stride exceeds inline storage slot size"
                )
                self._inlineElements = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
                self._count = 0
                self._heapStorage = nil
                self._heapIndices = nil
                unsafe (self._heapElementPtr = nil)
            }

            deinit {
                let count = _count
                guard count > 0 else { return }

                if _heapStorage != nil {
                    _heapStorage!.header = count
                } else {
                    let stride = MemoryLayout<Element>.stride
                    unsafe Swift.withUnsafeBytes(of: _inlineElements) { bytes in
                        let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                        for i in 0..<count {
                            let elementPtr = unsafe (basePtr + i * stride)
                                .assumingMemoryBound(to: Element.self)
                            unsafe elementPtr.deinitialize(count: 1)
                        }
                    }
                }
            }

            @inlinable
            public var isSpilled: Bool { _heapStorage != nil }

            @usableFromInline
            @unsafe
            mutating func _inlinePointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
                let stride = MemoryLayout<Element>.stride
                return unsafe Swift.withUnsafeMutablePointer(to: &_inlineElements) { storagePtr in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe (basePtr + index * stride)
                        .assumingMemoryBound(to: Element.self)
                    return unsafe elementPtr
                }
            }

            @usableFromInline
            @unsafe
            func _inlineReadPointerToElement(at index: Int) -> UnsafePointer<Element> {
                let stride = MemoryLayout<Element>.stride
                return unsafe Swift.withUnsafePointer(to: _inlineElements) { storagePtr in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe (basePtr + index * stride)
                        .assumingMemoryBound(to: Element.self)
                    return unsafe elementPtr
                }
            }

            @usableFromInline
            mutating func _spillToHeap(minimumCapacity: Int) {
                precondition(_heapStorage == nil, "Already spilled")

                let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
                let newStorage = ElementStorage.create(minimumCapacity: newCapacity)
                var newIndices = Hash.Table<Element>(minimumCapacity: newCapacity)

                let stride = MemoryLayout<Element>.stride
                _ = unsafe Swift.withUnsafeBytes(of: _inlineElements) { bytes in
                    unsafe newStorage.withUnsafeMutablePointerToElements { heapPtr in
                        let inlineBase = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                        for i in 0..<_count {
                            let inlineElement = unsafe (inlineBase + i * stride)
                                .assumingMemoryBound(to: Element.self)
                            let element = unsafe inlineElement.move()
                            let position = Index_Primitives.Index<Element>(__unchecked: (), position: i)
                            newIndices.insert(__unchecked: (), position: position, hashValue: element.hashValue)
                            unsafe (heapPtr + i).initialize(to: element)
                        }
                    }
                }
                newStorage.header = _count

                _heapStorage = newStorage
                _heapIndices = consume newIndices
                unsafe (_heapElementPtr = newStorage._elementsPointer)
            }
        }
    }
}

// MARK: - Conditional Copyable

/// `Set.Ordered` is `Copyable` when its element type is `Copyable`.
///
/// This enables value semantics with copy-on-write optimization:
/// copies share storage until mutation.
extension Set_Primitives_Core.Set.Ordered: Copyable where Element: Copyable {}

/// `Set.Ordered.Bounded` is `Copyable` when its element type is `Copyable`.
extension Set_Primitives_Core.Set.Ordered.Bounded: Copyable where Element: Copyable {}

// Note: Set.Ordered.Inline and Set.Ordered.Small are UNCONDITIONALLY ~Copyable
// because they have deinit for inline storage cleanup.

// MARK: - Conditional Sequence

/// `Set.Ordered` conforms to `Swift.Sequence` when `Element` is `Copyable`.
///
/// This enables `for-in` loops, `map`, `filter`, and other sequence operations.
/// For iteration without Copyable, use ``forEach(_:)`` instead.
extension Set_Primitives_Core.Set.Ordered: Swift.Sequence where Element: Copyable {
    // Note: Iterator is already defined below in the Iterator section.
    // Sequence conformance uses the existing makeIterator() method.
}

// MARK: - Initialization

extension Set_Primitives_Core.Set.Ordered {
    /// Creates an ordered set with reserved capacity.
    @inlinable
    public init(reservingCapacity capacity: Int) throws(__SetOrderedError) {
        guard capacity >= 0 else {
            throw .bounds(.init(index: capacity, count: 0))
        }
        self._elementStorage = ElementStorage.create(minimumCapacity: capacity)
        self._indices = Hash.Table(minimumCapacity: capacity)
        unsafe (self._cachedElementPtr = _elementStorage._elementsPointer)
    }

    /// Creates an ordered set containing the elements of a sequence.
    @inlinable
    public init<S: Swift.Sequence>(_ elements: S) where S.Element == Element {
        self.init()
        for element in elements {
            insert(element)
        }
    }
}

// MARK: - Properties

extension Set_Primitives_Core.Set.Ordered {
    /// The number of elements in the set.
    @inlinable
    public var count: Int { _elementStorage.header }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { _elementStorage.header == 0 }

    /// The current capacity of the set.
    @inlinable
    public var capacity: Int { _elementStorage.capacity }
}

// MARK: - Capacity Management

extension Set_Primitives_Core.Set.Ordered {
    @usableFromInline
    mutating func ensureCapacity(_ minimumCapacity: Int) {
        guard _elementStorage.capacity < minimumCapacity else { return }

        let newCapacity = Swift.max(minimumCapacity, _elementStorage.capacity * 2, 4)
        let newStorage = ElementStorage.create(minimumCapacity: newCapacity)
        let currentCount = _elementStorage.header

        _elementStorage._moveAllElements(to: newStorage)
        newStorage.header = currentCount
        _elementStorage = newStorage
        unsafe (_cachedElementPtr = _elementStorage._elementsPointer)
    }

    /// Reserves enough space to store the specified number of elements.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        makeUnique()
        // Hash.Table grows automatically; only reserve element storage
        ensureCapacity(minimumCapacity)
    }
}

// MARK: - Storage Uniqueness (CoW)

extension Set_Primitives_Core.Set.Ordered {
    /// Ensures element storage is uniquely owned (copy-on-write).
    ///
    /// When `Element` is `Copyable`, `Set.Ordered` supports copy-on-write semantics.
    /// This method copies storage if it's shared.
    ///
    /// When `Element` is `~Copyable`, `Set.Ordered` is also `~Copyable` and storage
    /// is always unique (the check will always pass).
    @usableFromInline
    @inline(__always)
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_elementStorage) {
            _elementStorage = _elementStorage.copy()
            unsafe (_cachedElementPtr = _elementStorage._elementsPointer)
            // Hash.Table uses class storage, so copying Set.Ordered shares it.
            // We need to rebuild the hash table after copying element storage.
            _indices = _rebuildIndices()
        }
    }

    /// Rebuilds hash table indices from current element storage.
    @usableFromInline
    func _rebuildIndices() -> Hash.Table<Element> {
        var newIndices = Hash.Table<Element>(minimumCapacity: count)
        for i in 0..<count {
            let element = _elementStorage._readElement(at: i)
            let position = Index_Primitives.Index<Element>(__unchecked: (), position: i)
            newIndices.insert(__unchecked: (), position: position, hashValue: element.hashValue)
        }
        return newIndices
    }
}

// MARK: - Core Operations

extension Set_Primitives_Core.Set.Ordered {
    /// Returns the index of the given element, or `nil` if not present.
    @inlinable
    public func index(_ element: Element) -> Int? {
        let position = _indices.position(
            forHash: element.hashValue,
            equals: { idx in _elementStorage._readElement(at: idx.position.rawValue) == element }
        )
        return position?.position.rawValue
    }

    /// Inserts an element into the set.
    @inlinable
    @discardableResult
    public mutating func insert(_ element: Element) -> (inserted: Bool, index: Int) {
        // Check for existing element
        if let existing = _indices.position(
            forHash: element.hashValue,
            equals: { idx in _elementStorage._readElement(at: idx.position.rawValue) == element }
        ) {
            return (false, existing.position.rawValue)
        }

        makeUnique()
        let index = _elementStorage.header
        ensureCapacity(index + 1)
        _elementStorage._initializeElement(at: index, to: element)
        _elementStorage.header = index + 1

        // Insert position into hash table
        let position = Index_Primitives.Index<Element>(__unchecked: (), position: index)
        _indices.insert(__unchecked: (), position: position, hashValue: element.hashValue)

        return (true, index)
    }

    /// Removes an element from the set.
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        guard let removedPosition = _indices.remove(
            hashValue: element.hashValue,
            equals: { idx in _elementStorage._readElement(at: idx.position.rawValue) == element }
        ) else {
            return nil
        }

        makeUnique()
        let removedIndex = removedPosition.position.rawValue
        let count = _elementStorage.header
        let removed = _elementStorage._moveElement(at: removedIndex)
        _elementStorage._shiftElementsLeftAndDecrement(removedAt: removedIndex, count: count)

        // Update hash table positions after removal
        _indices.decrementPositions(after: removedPosition)

        return removed
    }

    /// Returns whether the set contains the given element.
    @inlinable
    public func contains(_ element: Element) -> Bool {
        _indices.position(
            forHash: element.hashValue,
            equals: { idx in _elementStorage._readElement(at: idx.position.rawValue) == element }
        ) != nil
    }

    /// Removes all elements from the set.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        makeUnique()
        _elementStorage._deinitializeAllElements()
        _indices.removeAll(keepingCapacity: keepingCapacity)
        if !keepingCapacity {
            _elementStorage = ElementStorage.create(minimumCapacity: 0)
            unsafe (_cachedElementPtr = _elementStorage._elementsPointer)
        }
    }
}

// MARK: - Element Access

extension Set_Primitives_Core.Set.Ordered {
    /// Accesses the element at the specified index.
    @inlinable
    public func element(at index: Int) throws(__SetOrderedError) -> Element {
        guard index >= 0 && index < count else {
            throw .bounds(.init(index: index, count: count))
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

extension Set_Primitives_Core.Set.Ordered {
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

extension Set_Primitives_Core.Set.Ordered {
    /// Accesses the element at the given index via closure.
    ///
    /// - Parameters:
    ///   - index: The index of the element.
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The result of the closure.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withElement<R>(at index: Int, _ body: (borrowing Element) -> R) -> R {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return unsafe _elementStorage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + index).pointee)
        }
    }

    /// Iterates over all elements in the set.
    ///
    /// - Parameter body: A closure that receives each borrowed element.
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
    ///
    /// - Parameter body: A closure that receives each consumed element.
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

extension Set_Primitives_Core.Set.Ordered {
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
extension Set_Primitives_Core.Set.Ordered {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `withSpan` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
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
    /// - Warning: This is an escape hatch for C interop. Prefer `withMutableSpan` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
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

// MARK: - Sendable

extension Set_Primitives_Core.Set.Ordered: @unchecked Sendable where Element: Sendable {}
extension Set_Primitives_Core.Set.Ordered.Bounded: @unchecked Sendable where Element: Sendable {}
extension Set_Primitives_Core.Set.Ordered.Inline: @unchecked Sendable where Element: Sendable {}
extension Set_Primitives_Core.Set.Ordered.Small: @unchecked Sendable where Element: Sendable {}

// MARK: - Iterator (Copyable elements only)

// When Element: Copyable, Set.Ordered conforms to Swift.Sequence, enabling
// for-in loops, map, filter, and other sequence operations.
// For ~Copyable elements, use forEach() or index-based iteration instead.

extension Set_Primitives_Core.Set.Ordered where Element: Copyable {
    /// Iterator for Set.Ordered that copies elements for safe iteration.
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        var index: Int

        @usableFromInline
        let storage: ElementStorage

        @usableFromInline
        let count: Int

        @usableFromInline
        init(_ ordered: borrowing Set_Primitives_Core.Set<Element>.Ordered) {
            self.index = 0
            self.storage = ordered._elementStorage
            self.count = storage.header
        }

        @inlinable
        public mutating func next() -> Element? {
            guard index < count else { return nil }
            let element = storage._readElement(at: index)
            index += 1
            return element
        }
    }

    /// Returns an iterator over the elements of the set.
    ///
    /// This enables `for element in set` syntax without requiring
    /// Swift.Sequence conformance (which would require Copyable).
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        Iterator(self)
    }
}

extension Set_Primitives_Core.Set.Ordered.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: - Hash.Protocol Conformance

// Note: Set.Ordered conforms to Hash.Protocol (from hash-primitives) which supports
// ~Copyable types. Swift.Equatable and Swift.Hashable require Copyable and cannot
// be used with ~Copyable containers.

extension Set_Primitives_Core.Set.Ordered: Hash.`Protocol` {
    /// Compares two ordered sets for element-wise equality.
    ///
    /// Two ordered sets are equal if they contain the same elements in the same order.
    @inlinable
    public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for i in 0..<lhs.count {
            if lhs._elementStorage._readElement(at: i) != rhs._elementStorage._readElement(at: i) {
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
            _elementStorage._readElement(at: i).hash(into: &hasher)
        }
    }
}

// Note: Swift.Equatable, Swift.Hashable, ExpressibleByArrayLiteral, and
// CustomStringConvertible all require Copyable conformance. Since Set.Ordered
// is ~Copyable, we cannot conform to these protocols. Use Hash.Protocol's
// ==, !=, and hashValue instead.

// MARK: - Description (non-protocol)

#if !hasFeature(Embedded)
extension Set_Primitives_Core.Set.Ordered {
    /// A textual representation of the set.
    public var description: String {
        var result = "Set.Ordered(["
        var first = true
        for i in 0..<count {
            if !first { result += ", " }
            result += String(describing: _elementStorage._readElement(at: i))
            first = false
        }
        result += "])"
        return result
    }
}
#endif

// MARK: - Internal Identity (for testing)

extension Set_Primitives_Core.Set.Ordered {
    @usableFromInline
    internal var _identity: ObjectIdentifier {
        ObjectIdentifier(_elementStorage)
    }
}
