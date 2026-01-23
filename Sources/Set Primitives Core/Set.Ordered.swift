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
// - Elements can be ~Copyable (using Hash.Protocol, not Hashable)
// - Container is conditionally Copyable when Element is Copyable
// - Operations use consuming/borrowing semantics for ~Copyable support
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

        // MARK: - ElementStorage (nested to inherit ~Copyable context)

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
            var elementsPointer: UnsafeMutablePointer<Element> {
                unsafe withUnsafeMutablePointerToElements { unsafe $0 }
            }

            /// Initializes element at the given index.
            @usableFromInline
            func initializeElement(at index: Int, to element: consuming Element) {
                let ptr = unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
                unsafe ptr.initialize(to: element)
            }

            /// Provides borrowing access to the element at the given index.
            @usableFromInline
            func withElement<R>(at index: Int, _ body: (borrowing Element) -> R) -> R {
                unsafe withUnsafeMutablePointerToElements { elements in
                    body(unsafe (elements + index).pointee)
                }
            }

            /// Moves element from the given index.
            @usableFromInline
            func moveElement(at index: Int) -> Element {
                unsafe withUnsafeMutablePointerToElements { elements in
                    unsafe (elements + index).move()
                }
            }

            /// Shifts elements left from `from` to fill gap at removed index.
            @usableFromInline
            func shiftElementsLeftAndDecrement(removedAt index: Int, count: Int) {
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
            func moveAllElements(to newStorage: ElementStorage) {
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

            /// Deinitializes all elements.
            @usableFromInline
            func deinitializeAllElements() {
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
            func deinitializeElements(from startIndex: Int, count: Int) {
                guard count > 0 else { return }
                _ = unsafe withUnsafeMutablePointerToElements { elements in
                    for i in startIndex..<(startIndex + count) {
                        unsafe (elements + i).deinitialize(count: 1)
                    }
                }
            }
        }

        // MARK: - IndexStorage (nested to inherit ~Copyable context)

        // ===------------------------------------------------------------------===//
        // TEMPORARY: Hash.Table Replacement
        // ===------------------------------------------------------------------===//
        //
        // This class is a workaround for a Swift compiler limitation where ~Copyable
        // constraints do not propagate correctly across module boundaries when using
        // generic types as stored properties.
        //
        // ## The Problem
        //
        // When `Hash.Table<Element>` from `Hash_Table_Primitives` was used as a stored
        // property in `Set.Ordered`, the compiler failed with:
        //
        //     error: type 'Element' does not conform to protocol 'Copyable'
        //
        // This occurred despite `Hash.Table` being declared as:
        //
        //     public struct Table<Element: ~Copyable>: ~Copyable { ... }
        //
        // The constraint `Element: ~Copyable` was not propagating through the
        // cross-module generic instantiation.
        //
        // ## The Solution
        //
        // By declaring `IndexStorage` as a nested class inside `Set.Ordered`, it
        // automatically inherits the `Element` generic parameter from the enclosing
        // `Set<Element>` enum. This keeps the ~Copyable constraint within the same
        // compilation unit, allowing proper propagation.
        //
        // ## Refactoring Back to Hash.Table
        //
        // Once the Swift compiler properly supports ~Copyable constraint propagation
        // across module boundaries (tracked in Swift issue #86669 or related), this
        // class should be removed and replaced with:
        //
        //     @usableFromInline
        //     var _indices: Hash.Table<Element>
        //
        // The hash table operations (findPosition, insertPosition, removePosition,
        // decrementPositions, clearIndices, growIndices) should then delegate to
        // the Hash.Table methods.
        //
        // See also:
        // - /Users/coen/Developer/swift-institute/.../Copyable Remediation.md
        // - Pattern used in swift-stack-primitives (Stack.Storage)
        //
        // ===------------------------------------------------------------------===//

        /// Internal hash index storage using ManagedBuffer.
        ///
        /// Stores (hash, position) pairs for O(1) element lookup.
        /// Declared nested to inherit Element's ~Copyable context from Set<Element>.
        ///
        /// - Important: This is a temporary workaround. See the comment block above
        ///   for context and refactoring guidance.
        @usableFromInline
        final class IndexStorage: ManagedBuffer<(count: Int, occupied: Int, hashCapacity: Int), Int> {

            /// Sentinel value indicating an empty bucket.
            @usableFromInline
            static var empty: Int { 0 }

            /// Sentinel value indicating a deleted bucket.
            @usableFromInline
            static var deleted: Int { Int.min }

            /// Creates storage with the specified hash capacity.
            @usableFromInline
            static func create(hashCapacity: Int) -> IndexStorage {
                // Allocate space for hashes + positions
                let storage = IndexStorage.create(minimumCapacity: hashCapacity * 2) { _ in
                    (count: 0, occupied: 0, hashCapacity: hashCapacity)
                }
                // Initialize all slots to empty (0)
                _ = unsafe storage.withUnsafeMutablePointerToElements { elements in
                    unsafe elements.initialize(repeating: IndexStorage.empty, count: hashCapacity * 2)
                }
                return unsafe unsafeDowncast(storage, to: IndexStorage.self)
            }

            deinit {
                // ManagedBuffer handles deallocation automatically
            }

            /// Reads hash at bucket index.
            @usableFromInline
            func readHash(at bucket: Int) -> Int {
                unsafe withUnsafeMutablePointerToElements { unsafe $0[bucket] }
            }

            /// Reads position at bucket index.
            @usableFromInline
            func readPosition(at bucket: Int) -> Int {
                let hashCapacity = header.hashCapacity
                return unsafe withUnsafeMutablePointerToElements { unsafe $0[hashCapacity + bucket] }
            }

            /// Writes hash at bucket index.
            @usableFromInline
            func writeHash(at bucket: Int, value: Int) {
                unsafe withUnsafeMutablePointerToElements { unsafe $0[bucket] = value }
            }

            /// Writes position at bucket index.
            @usableFromInline
            func writePosition(at bucket: Int, value: Int) {
                let hashCapacity = header.hashCapacity
                unsafe withUnsafeMutablePointerToElements { unsafe $0[hashCapacity + bucket] = value }
            }

            /// Computes the actual capacity for a given minimum capacity.
            /// Uses power-of-two sizing for fast modulo via bitmasking.
            @usableFromInline
            static func capacity(for minimumCapacity: Int) -> Int {
                guard minimumCapacity > 0 else { return 8 }
                // Target ~70% load factor
                let needed = Swift.max(8, (minimumCapacity * 10) / 7)
                // Round up to next power of two
                return 1 << (Int.bitWidth - (needed - 1).leadingZeroBitCount)
            }

            /// Normalizes a hash value to avoid sentinel collisions.
            @usableFromInline
            static func normalize(_ hashValue: Int) -> Int {
                let hash = hashValue == 0 ? 1 : hashValue
                return hash == Int.min ? 1 : hash
            }

            /// Computes the initial bucket for a hash value.
            @usableFromInline
            static func bucket(for hash: Int, capacity: Int) -> Int {
                // capacity is power of two, so we can use bitmasking
                hash & (capacity - 1)
            }

            /// Computes the next bucket in the probe sequence.
            @usableFromInline
            static func nextBucket(_ bucket: Int, capacity: Int) -> Int {
                (bucket + 1) & (capacity - 1)
            }

            // MARK: - Slot (probe result)

            /// Result of probing the hash table for a position.
            @usableFromInline
            enum Slot {
                /// Found an existing entry at the given bucket.
                case found(position: Int, bucket: Int, normalizedHash: Int)
                /// Found an empty or deleted bucket where insertion can occur.
                case vacant(bucket: Int, normalizedHash: Int)
            }

            // MARK: - Core Operations

            /// Finds a slot for the given hash value.
            ///
            /// - Parameters:
            ///   - hashValue: The raw hash value to probe for.
            ///   - equals: A closure that checks if the element at a position matches.
            /// - Returns: Either `.found` with the position or `.vacant` with the first available bucket.
            @usableFromInline
            func findSlot(hashValue: Int, equals: (Int) -> Bool) -> Slot {
                let hash = IndexStorage.normalize(hashValue)
                let hashCapacity = header.hashCapacity
                var bucket = IndexStorage.bucket(for: hash, capacity: hashCapacity)
                var firstTombstone: Int? = nil

                while true {
                    let storedHash = readHash(at: bucket)

                    if storedHash == IndexStorage.empty {
                        // Empty slot - return first tombstone if we passed one, else this bucket
                        let insertBucket = firstTombstone ?? bucket
                        return .vacant(bucket: insertBucket, normalizedHash: hash)
                    }

                    if storedHash == IndexStorage.deleted {
                        // Remember first tombstone for potential insertion
                        if firstTombstone == nil {
                            firstTombstone = bucket
                        }
                    } else if storedHash == hash {
                        let position = readPosition(at: bucket)
                        if equals(position) {
                            return .found(position: position, bucket: bucket, normalizedHash: hash)
                        }
                    }

                    bucket = IndexStorage.nextBucket(bucket, capacity: hashCapacity)
                }
            }

            /// Inserts a position at the given bucket.
            ///
            /// - Parameters:
            ///   - position: The element position to store.
            ///   - bucket: The bucket index (from a `.vacant` slot).
            ///   - normalizedHash: The normalized hash value.
            @usableFromInline
            func insert(position: Int, at bucket: Int, normalizedHash: Int) {
                let wasEmpty = readHash(at: bucket) == IndexStorage.empty
                writeHash(at: bucket, value: normalizedHash)
                writePosition(at: bucket, value: position)
                header.count += 1
                if wasEmpty {
                    header.occupied += 1
                }
            }

            /// Marks a bucket as deleted.
            ///
            /// - Parameter bucket: The bucket index to mark as deleted.
            @usableFromInline
            func markDeleted(at bucket: Int) {
                writeHash(at: bucket, value: IndexStorage.deleted)
                header.count -= 1
            }

            /// Decrements all positions greater than the removed position.
            ///
            /// Called after element removal to maintain correct position references.
            @usableFromInline
            func decrementPositions(after removedPosition: Int) {
                let hashCapacity = header.hashCapacity
                for i in 0..<hashCapacity {
                    let hash = readHash(at: i)
                    if hash != IndexStorage.empty && hash != IndexStorage.deleted {
                        let pos = readPosition(at: i)
                        if pos > removedPosition {
                            writePosition(at: i, value: pos - 1)
                        }
                    }
                }
            }

            /// Clears all entries in the hash table.
            @usableFromInline
            func clear() {
                let hashCapacity = header.hashCapacity
                for i in 0..<hashCapacity {
                    writeHash(at: i, value: IndexStorage.empty)
                }
                header.count = 0
                header.occupied = 0
            }

            /// Creates a copy of this index storage.
            ///
            /// - Returns: A new `IndexStorage` with the same entries.
            @usableFromInline
            func copyBuffer() -> IndexStorage {
                let hashCapacity = header.hashCapacity
                let newStorage = IndexStorage.create(hashCapacity: hashCapacity)

                // Copy all data (hashes + positions)
                _ = unsafe withUnsafeMutablePointerToElements { src in
                    unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                        unsafe dst.update(from: src, count: hashCapacity * 2)
                    }
                }

                newStorage.header.count = header.count
                newStorage.header.occupied = header.occupied
                return newStorage
            }
        }

        @usableFromInline
        var elementStorage: ElementStorage

        /// Hash index storage for O(1) lookup.
        @usableFromInline
        var indexStorage: IndexStorage

        /// Cached pointer to element storage.
        @usableFromInline
        var cachedElementPtr: UnsafeMutablePointer<Element>

        /// Creates an empty ordered set.
        @inlinable
        public init() {
            self.elementStorage = ElementStorage.create(minimumCapacity: 0)
            self.indexStorage = IndexStorage.create(hashCapacity: IndexStorage.capacity(for: 0))
            unsafe (self.cachedElementPtr = elementStorage.elementsPointer)
        }

        // MARK: - Hash Table Operations

        /// Finds the position for an element with the given hash value.
        @usableFromInline
        func findPosition(forHash hashValue: Int, equals: (Int) -> Bool) -> Int? {
            switch indexStorage.findSlot(hashValue: hashValue, equals: equals) {
            case .found(let position, _, _):
                return position
            case .vacant:
                return nil
            }
        }

        /// Whether the hash table should grow.
        @usableFromInline
        var shouldGrowIndices: Bool {
            let hashCapacity = indexStorage.header.hashCapacity
            let occupied = indexStorage.header.occupied
            // Grow when occupied exceeds 70% of capacity
            return occupied * 10 >= hashCapacity * 7
        }

        /// Doubles the capacity and rehashes all elements.
        @usableFromInline
        mutating func growIndices() {
            let oldCapacity = indexStorage.header.hashCapacity
            let newCapacity = Swift.max(8, oldCapacity * 2)
            let newStorage = IndexStorage.create(hashCapacity: newCapacity)

            for i in 0..<oldCapacity {
                let hash = indexStorage.readHash(at: i)
                if hash != IndexStorage.empty && hash != IndexStorage.deleted {
                    let position = indexStorage.readPosition(at: i)
                    var bucket = IndexStorage.bucket(for: hash, capacity: newCapacity)

                    while newStorage.readHash(at: bucket) != IndexStorage.empty {
                        bucket = IndexStorage.nextBucket(bucket, capacity: newCapacity)
                    }

                    newStorage.writeHash(at: bucket, value: hash)
                    newStorage.writePosition(at: bucket, value: position)
                }
            }

            newStorage.header.count = indexStorage.header.count
            newStorage.header.occupied = indexStorage.header.count
            indexStorage = newStorage
        }

        /// Inserts a position into the hash table without checking for duplicates.
        @usableFromInline
        mutating func insertPosition(position: Int, hashValue: Int) {
            if shouldGrowIndices {
                growIndices()
            }

            // Use a non-matching equals closure since we're inserting a new position
            switch indexStorage.findSlot(hashValue: hashValue, equals: { _ in false }) {
            case .vacant(let bucket, let normalizedHash):
                indexStorage.insert(position: position, at: bucket, normalizedHash: normalizedHash)
            case .found:
                fatalError("Unreachable: equals always returns false")
            }
        }

        /// Removes a position from the hash table.
        @usableFromInline
        mutating func removePosition(hashValue: Int, equals: (Int) -> Bool) -> Int? {
            switch indexStorage.findSlot(hashValue: hashValue, equals: equals) {
            case .found(let position, let bucket, _):
                indexStorage.markDeleted(at: bucket)
                return position
            case .vacant:
                return nil
            }
        }

        /// Updates positions after an element is removed from element storage.
        @usableFromInline
        mutating func decrementPositions(after removedPosition: Int) {
            indexStorage.decrementPositions(after: removedPosition)
        }

        /// Removes all entries from the hash table.
        @usableFromInline
        mutating func clearIndices(keepingCapacity: Bool) {
            if keepingCapacity {
                indexStorage.clear()
            } else {
                // Create new storage with default capacity
                let hashCapacity = IndexStorage.capacity(for: 0)
                indexStorage = IndexStorage.create(hashCapacity: hashCapacity)
            }
        }

        // MARK: - Bounded Variant

        /// A fixed-capacity ordered set that throws on overflow.
        ///
        /// `Set.Ordered.Bounded` allocates storage upfront and throws when
        /// inserting an element would exceed the capacity.
        @safe
        public struct Bounded {
            @usableFromInline
            var elementStorage: ElementStorage

            @usableFromInline
            var indexStorage: IndexStorage

            @usableFromInline
            var cachedElementPtr: UnsafeMutablePointer<Element>

            /// The maximum number of elements the set can hold.
            public let capacity: Int

            /// Creates a bounded ordered set with the specified capacity.
            @inlinable
            public init(capacity: Int) throws(__SetOrderedBoundedError) {
                guard capacity >= 0 else {
                    throw .invalidCapacity(.init())
                }
                self.elementStorage = ElementStorage.create(minimumCapacity: capacity)
                self.indexStorage = IndexStorage.create(hashCapacity: IndexStorage.capacity(for: capacity))
                unsafe (self.cachedElementPtr = elementStorage.elementsPointer)
                self.capacity = capacity
            }

            // MARK: - Hash Table Operations (Bounded)

            @usableFromInline
            func findPosition(forHash hashValue: Int, equals: (Int) -> Bool) -> Int? {
                switch indexStorage.findSlot(hashValue: hashValue, equals: equals) {
                case .found(let position, _, _):
                    return position
                case .vacant:
                    return nil
                }
            }

            @usableFromInline
            mutating func insertPosition(position: Int, hashValue: Int) {
                // Bounded variant doesn't grow - capacity is fixed at creation
                switch indexStorage.findSlot(hashValue: hashValue, equals: { _ in false }) {
                case .vacant(let bucket, let normalizedHash):
                    indexStorage.insert(position: position, at: bucket, normalizedHash: normalizedHash)
                case .found:
                    fatalError("Unreachable: equals always returns false")
                }
            }

            @usableFromInline
            mutating func removePosition(hashValue: Int, equals: (Int) -> Bool) -> Int? {
                switch indexStorage.findSlot(hashValue: hashValue, equals: equals) {
                case .found(let position, let bucket, _):
                    indexStorage.markDeleted(at: bucket)
                    return position
                case .vacant:
                    return nil
                }
            }

            @usableFromInline
            mutating func decrementPositions(after removedPosition: Int) {
                indexStorage.decrementPositions(after: removedPosition)
            }

            @usableFromInline
            mutating func clearIndices(keepingCapacity: Bool) {
                // Bounded always keeps capacity
                indexStorage.clear()
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
            static var maxElementStride: Int { 64 }

            /// Raw byte storage for elements.
            @usableFromInline
            var elements: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

            /// Current element count.
            @usableFromInline
            var storedCount: Int

            /// Workaround for Swift compiler bug with InlineArray + value generic deinit.
            /// Per [COPY-FIX-009].
            @usableFromInline
            var _deinitWorkaround: AnyObject? = nil

            /// Creates an empty inline ordered set.
            @inlinable
            public init() {
                precondition(
                    MemoryLayout<Element>.stride <= Self.maxElementStride,
                    "Element stride exceeds inline storage slot size"
                )
                self.elements = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
                self.storedCount = 0
            }

            deinit {
                let count = storedCount
                guard count > 0 else { return }

                let stride = MemoryLayout<Element>.stride
                unsafe Swift.withUnsafeBytes(of: elements) { bytes in
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
            mutating func pointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
                let stride = MemoryLayout<Element>.stride
                return unsafe Swift.withUnsafeMutablePointer(to: &elements) { storagePtr in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe (basePtr + index * stride)
                        .assumingMemoryBound(to: Element.self)
                    return unsafe elementPtr
                }
            }

            @usableFromInline
            @unsafe
            func readPointerToElement(at index: Int) -> UnsafePointer<Element> {
                let stride = MemoryLayout<Element>.stride
                return unsafe Swift.withUnsafePointer(to: elements) { storagePtr in
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
            static var maxElementStride: Int { 64 }

            @usableFromInline
            var inlineElements: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

            @usableFromInline
            var storedCount: Int

            @usableFromInline
            var heapStorage: ElementStorage?

            @usableFromInline
            var heapIndexStorage: IndexStorage?

            @usableFromInline
            var heapElementPtr: UnsafeMutablePointer<Element>?

            /// Workaround for Swift compiler bug with InlineArray + value generic deinit.
            @usableFromInline
            var _deinitWorkaround: AnyObject? = nil

            @inlinable
            public init() {
                precondition(
                    MemoryLayout<Element>.stride <= Self.maxElementStride,
                    "Element stride exceeds inline storage slot size"
                )
                self.inlineElements = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
                self.storedCount = 0
                self.heapStorage = nil
                self.heapIndexStorage = nil
                unsafe (self.heapElementPtr = nil)
            }

            deinit {
                let count = storedCount
                guard count > 0 else { return }

                if heapStorage != nil {
                    heapStorage!.header = count
                } else {
                    let stride = MemoryLayout<Element>.stride
                    unsafe Swift.withUnsafeBytes(of: inlineElements) { bytes in
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
            public var isSpilled: Bool { heapStorage != nil }

            @usableFromInline
            @unsafe
            mutating func inlinePointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
                let stride = MemoryLayout<Element>.stride
                return unsafe Swift.withUnsafeMutablePointer(to: &inlineElements) { storagePtr in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe (basePtr + index * stride)
                        .assumingMemoryBound(to: Element.self)
                    return unsafe elementPtr
                }
            }

            @usableFromInline
            @unsafe
            func inlineReadPointerToElement(at index: Int) -> UnsafePointer<Element> {
                let stride = MemoryLayout<Element>.stride
                return unsafe Swift.withUnsafePointer(to: inlineElements) { storagePtr in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe (basePtr + index * stride)
                        .assumingMemoryBound(to: Element.self)
                    return unsafe elementPtr
                }
            }

            @usableFromInline
            mutating func spillToHeap(minimumCapacity: Int) {
                precondition(heapStorage == nil, "Already spilled")

                let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
                let newStorage = ElementStorage.create(minimumCapacity: newCapacity)
                let newIndexStorage = IndexStorage.create(hashCapacity: IndexStorage.capacity(for: newCapacity))

                let stride = MemoryLayout<Element>.stride
                _ = unsafe Swift.withUnsafeBytes(of: inlineElements) { bytes in
                    unsafe newStorage.withUnsafeMutablePointerToElements { heapPtr in
                        let inlineBase = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                        for i in 0..<count {
                            let inlineElement = unsafe (inlineBase + i * stride)
                                .assumingMemoryBound(to: Element.self)
                            let element = unsafe inlineElement.move()
                            let hashValue = element.hashValue
                            unsafe (heapPtr + i).initialize(to: element)

                            // Insert into hash table using IndexStorage.findSlot + insert
                            switch newIndexStorage.findSlot(hashValue: hashValue, equals: { _ in false }) {
                            case .vacant(let bucket, let normalizedHash):
                                newIndexStorage.insert(position: i, at: bucket, normalizedHash: normalizedHash)
                            case .found:
                                fatalError("Unreachable: equals always returns false")
                            }
                        }
                    }
                }
                newStorage.header = count

                heapStorage = newStorage
                heapIndexStorage = newIndexStorage
                unsafe (heapElementPtr = newStorage.elementsPointer)
            }

            // MARK: - Hash Table Operations (Small - heap mode only)

            @usableFromInline
            func findHeapPosition(forHash hashValue: Int, equals: (Int) -> Bool) -> Int? {
                guard let indexStorage = heapIndexStorage else { return nil }
                switch indexStorage.findSlot(hashValue: hashValue, equals: equals) {
                case .found(let position, _, _):
                    return position
                case .vacant:
                    return nil
                }
            }

            @usableFromInline
            mutating func insertHeapPosition(position: Int, hashValue: Int) {
                guard let indexStorage = heapIndexStorage else { return }
                switch indexStorage.findSlot(hashValue: hashValue, equals: { _ in false }) {
                case .vacant(let bucket, let normalizedHash):
                    indexStorage.insert(position: position, at: bucket, normalizedHash: normalizedHash)
                case .found:
                    fatalError("Unreachable: equals always returns false")
                }
            }

            @usableFromInline
            mutating func removeHeapPosition(hashValue: Int, equals: (Int) -> Bool) -> Int? {
                guard let indexStorage = heapIndexStorage else { return nil }
                switch indexStorage.findSlot(hashValue: hashValue, equals: equals) {
                case .found(let position, let bucket, _):
                    indexStorage.markDeleted(at: bucket)
                    return position
                case .vacant:
                    return nil
                }
            }

            @usableFromInline
            mutating func decrementHeapPositions(after removedPosition: Int) {
                guard let indexStorage = heapIndexStorage else { return }
                indexStorage.decrementPositions(after: removedPosition)
            }

            @usableFromInline
            mutating func clearHeapIndices(keepingCapacity: Bool) {
                guard let indexStorage = heapIndexStorage else { return }
                indexStorage.clear()
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
        self.elementStorage = ElementStorage.create(minimumCapacity: capacity)
        self.indexStorage = IndexStorage.create(hashCapacity: IndexStorage.capacity(for: capacity))
        unsafe (self.cachedElementPtr = elementStorage.elementsPointer)
    }
}

extension Set_Primitives_Core.Set.Ordered where Element: Copyable {
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
    public var count: Int { elementStorage.header }

    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { elementStorage.header == 0 }

    /// The current capacity of the set.
    @inlinable
    public var capacity: Int { elementStorage.capacity }
}

// MARK: - Capacity Management

extension Set_Primitives_Core.Set.Ordered {
    @usableFromInline
    mutating func ensureCapacity(_ minimumCapacity: Int) {
        guard elementStorage.capacity < minimumCapacity else { return }

        let newCapacity = Swift.max(minimumCapacity, elementStorage.capacity * 2, 4)
        let newStorage = ElementStorage.create(minimumCapacity: newCapacity)
        let currentCount = elementStorage.header

        elementStorage.moveAllElements(to: newStorage)
        newStorage.header = currentCount
        elementStorage = newStorage
        unsafe (cachedElementPtr = elementStorage.elementsPointer)
    }

    /// Reserves enough space to store the specified number of elements.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        // Hash table grows automatically; only reserve element storage
        ensureCapacity(minimumCapacity)
    }
}

// MARK: - Storage Uniqueness (CoW) - Copyable elements only

extension Set_Primitives_Core.Set.Ordered where Element: Copyable {
    /// Ensures element storage is uniquely owned (copy-on-write).
    ///
    /// Copies both element storage and index storage together to maintain
    /// consistency. Uses O(capacity) memcpy for index storage instead of
    /// O(n) rehashing.
    @usableFromInline
    @inline(__always)
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&elementStorage) {
            elementStorage = elementStorage.copy()
            indexStorage = indexStorage.copyBuffer()
            // CRITICAL: Update cached pointer after copy
            unsafe (cachedElementPtr = elementStorage.elementsPointer)
        }
    }
}

// MARK: - Core Operations (Copyable - with CoW)

extension Set_Primitives_Core.Set.Ordered where Element: Copyable {
    /// Returns the index of the given element, or `nil` if not present.
    @inlinable
    public func index(_ element: Element) -> Int? {
        findPosition(
            forHash: element.hashValue,
            equals: { idx in elementStorage.readElement(at: idx) == element }
        )
    }

    /// Inserts an element into the set (CoW-aware).
    @inlinable
    @discardableResult
    public mutating func insert(_ element: Element) -> (inserted: Bool, index: Int) {
        // Check for existing element
        if let existing = findPosition(
            forHash: element.hashValue,
            equals: { idx in elementStorage.readElement(at: idx) == element }
        ) {
            return (false, existing)
        }

        makeUnique()
        let index = elementStorage.header
        ensureCapacity(index + 1)
        elementStorage.initializeElement(at: index, to: element)
        elementStorage.header = index + 1

        // Insert position into hash table
        insertPosition(position: index, hashValue: element.hashValue)

        return (true, index)
    }

    /// Removes an element from the set (CoW-aware).
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        // makeUnique() must be called first because it may rebuild the hash table
        // from element storage - if we remove from hash table first, the rebuild
        // would re-add the element.
        makeUnique()

        // Capture storage reference to avoid overlapping access
        let storage = elementStorage
        let hashValue = element.hashValue
        guard let removedPosition = removePosition(
            hashValue: hashValue,
            equals: { idx in storage.readElement(at: idx) == element }
        ) else {
            return nil
        }

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

    /// Removes all elements from the set (CoW-aware).
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        makeUnique()
        elementStorage.deinitializeAllElements()
        clearIndices(keepingCapacity: keepingCapacity)
        if !keepingCapacity {
            elementStorage = ElementStorage.create(minimumCapacity: 0)
            unsafe (cachedElementPtr = elementStorage.elementsPointer)
        }
    }
}

// MARK: - Element Access (Copyable only - returns copies)

extension Set_Primitives_Core.Set.Ordered where Element: Copyable {
    /// Accesses the element at the specified index.
    ///
    /// Returns a copy of the element. For `~Copyable` elements, use ``withElement(at:_:)`` instead.
    @inlinable
    public func element(at index: Int) throws(__SetOrderedError) -> Element {
        guard index >= 0 && index < count else {
            throw .bounds(.init(index: index, count: count))
        }
        return elementStorage.readElement(at: index)
    }

    /// Subscript access to elements by index.
    ///
    /// Returns a copy of the element. For `~Copyable` elements, use ``withElement(at:_:)`` instead.
    @inlinable
    public subscript(index: Int) -> Element {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return elementStorage.readElement(at: index)
    }
}

// MARK: - First/Last Accessors (Copyable only - returns copies)

extension Set_Primitives_Core.Set.Ordered where Element: Copyable {
    /// The first element, or `nil` if the set is empty.
    ///
    /// Returns a copy. For `~Copyable` elements, use `withElement(at: 0, _:)`.
    @inlinable
    public var first: Element? {
        count > 0 ? elementStorage.readElement(at: 0) : nil
    }

    /// The last element, or `nil` if the set is empty.
    ///
    /// Returns a copy. For `~Copyable` elements, use `withElement(at: count - 1, _:)`.
    @inlinable
    public var last: Element? {
        count > 0 ? elementStorage.readElement(at: count - 1) : nil
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
        return unsafe elementStorage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + index).pointee)
        }
    }

    /// Iterates over all elements in the set.
    ///
    /// - Parameter body: A closure that receives each borrowed element.
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
}

extension Set_Primitives_Core.Set.Ordered where Element: Copyable {
    /// Removes and consumes all elements.
    ///
    /// - Parameter body: A closure that receives each consumed element.
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
            let count = elementStorage.header
            // cachedElementPtr from ManagedBuffer is always valid; pointer irrelevant when count == 0
            return unsafe Span(_unsafeStart: cachedElementPtr, count: count)
        }
    }
}

extension Set_Primitives_Core.Set.Ordered where Element: Copyable {
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
        let count = elementStorage.header
        if count > 0 {
            return try unsafe body(UnsafeBufferPointer(start: cachedElementPtr, count: count))
        } else {
            return try unsafe body(UnsafeBufferPointer(start: nil, count: 0))
        }
    }
}

@_spi(Unsafe)
extension Set_Primitives_Core.Set.Ordered where Element: Copyable {
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
        let count = elementStorage.header
        if count > 0 {
            return try unsafe body(UnsafeMutableBufferPointer(start: cachedElementPtr, count: count))
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
            self.storage = ordered.elementStorage
            self.count = storage.header
        }

        @inlinable
        public mutating func next() -> Element? {
            guard index < count else { return nil }
            let element = storage.readElement(at: index)
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
    /// Uses borrowing comparison to support `~Copyable` elements.
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
    ///
    /// Uses borrowing access to support `~Copyable` elements.
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

// Note: Swift.Equatable, Swift.Hashable, ExpressibleByArrayLiteral, and
// CustomStringConvertible all require Copyable conformance. Since Set.Ordered
// is ~Copyable, we cannot conform to these protocols. Use Hash.Protocol's
// ==, !=, and hashValue instead.

// MARK: - Description (non-protocol, Copyable only)

#if !hasFeature(Embedded)
extension Set_Primitives_Core.Set.Ordered where Element: Copyable {
    /// A textual representation of the set.
    ///
    /// Only available when `Element: Copyable` since elements are copied for description.
    public var description: String {
        var result = "Set.Ordered(["
        var first = true
        for i in 0..<count {
            if !first { result += ", " }
            result += String(describing: elementStorage.readElement(at: i))
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
        ObjectIdentifier(elementStorage)
    }
}

// MARK: - ElementStorage Copyable Helpers

extension Set_Primitives_Core.Set.Ordered.ElementStorage where Element: Copyable {
    /// Reads element at the given index (returns a copy).
    @usableFromInline
    func readElement(at index: Int) -> Element {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe elements[index]
        }
    }

    /// Copies all elements to new storage.
    @usableFromInline
    func copyAllElements(to newStorage: Set_Primitives_Core.Set<Element>.Ordered.ElementStorage) {
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
    func copy() -> Set_Primitives_Core.Set<Element>.Ordered.ElementStorage {
        let count = header
        guard count > 0 else {
            return Set_Primitives_Core.Set<Element>.Ordered.ElementStorage.create(minimumCapacity: 0)
        }

        let new = Set_Primitives_Core.Set<Element>.Ordered.ElementStorage.create(minimumCapacity: capacity)
        new.header = count
        copyAllElements(to: new)
        return new
    }
}
