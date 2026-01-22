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

extension Set_Primitives.Set.Ordered.Consuming {
    /// An iterator that consumes elements from an ordered set.
    ///
    /// `Iterator` is `~Copyable` because it represents exclusive ownership
    /// over the set's elements. Each call to ``next()`` moves an element out
    /// of the set's storage.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// func process(nodes: consuming Set<Node>.Ordered) {
    ///     var iterator = nodes.makeConsumingIterator()
    ///     while let node = iterator.next() {
    ///         // node is owned, can be moved or consumed
    ///     }
    /// }
    /// ```
    ///
    /// ## Partial Consumption
    ///
    /// If iteration stops early (e.g., via `break` or error), remaining
    /// elements are properly deinitialized when the iterator is destroyed.
    ///
    /// ## Complexity
    ///
    /// - `next()`: O(1)
    /// - Deinit with remaining elements: O(n) where n is remaining count
    @safe
    public struct Iterator: ~Copyable {
        /// The element storage taken from the set.
        @usableFromInline
        let _storage: Set_Primitives.Set<Element>.Ordered.ElementStorage

        /// Current position in the storage.
        @usableFromInline
        var _index: Int

        /// Total number of elements (captured at creation).
        @usableFromInline
        let _count: Int

        /// Creates an iterator that consumes the given set.
        ///
        /// - Parameter set: The set to consume. Ownership is transferred to the iterator.
        @usableFromInline
        init(_consuming set: consuming Set_Primitives.Set<Element>.Ordered) {
            // Ensure unique ownership of storage before consuming.
            // This is necessary because the set may share storage with copies.
            var mutableSet = set
            mutableSet.makeUnique()

            self._storage = mutableSet._elementStorage
            self._index = 0
            self._count = _storage.header

            // Mark storage as empty so its deinit won't double-free elements.
            // We take responsibility for cleaning up remaining elements.
            _storage.header = 0
        }

        /// Returns the next element, or `nil` if iteration is complete.
        ///
        /// Each call moves an element out of the storage, transferring
        /// ownership to the caller.
        ///
        /// - Complexity: O(1)
        @inlinable
        public mutating func next() -> Element? {
            guard _index < _count else { return nil }
            let element = _storage._moveElement(at: _index)
            _index += 1
            return element
        }

        deinit {
            // Clean up any elements that weren't consumed.
            // We call a helper method on storage to avoid compiler issues
            // with ~Copyable + unsafe in deinit.
            _storage._deinitializeElements(from: _index, count: _count - _index)
        }
    }
}

// MARK: - Sendable

extension Set_Primitives.Set.Ordered.Consuming.Iterator: @unchecked Sendable where Element: Sendable {}
