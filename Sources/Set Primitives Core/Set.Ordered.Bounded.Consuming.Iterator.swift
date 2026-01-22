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

extension Set_Primitives_Core.Set.Ordered.Bounded.Consuming {
    /// An iterator that consumes elements from a bounded ordered set.
    ///
    /// `Iterator` is `~Copyable` because it represents exclusive ownership
    /// over the set's elements. Each call to ``next()`` moves an element out
    /// of the set's storage.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// func process(nodes: consuming Set<Node>.Ordered.Bounded) {
    ///     var iterator = nodes.makeConsumingIterator()
    ///     while let node = iterator.next() {
    ///         // node is owned, can be moved or consumed
    ///     }
    /// }
    /// ```
    ///
    /// ## Partial Consumption
    ///
    /// If iteration stops early, remaining elements are properly deinitialized
    /// when the iterator is destroyed.
    @safe
    public struct Iterator: ~Copyable {
        @usableFromInline
        let _storage: Set_Primitives_Core.Set<Element>.Ordered.ElementStorage

        @usableFromInline
        var _index: Int

        @usableFromInline
        let _count: Int

        @usableFromInline
        init(_consuming set: consuming Set_Primitives_Core.Set<Element>.Ordered.Bounded) {
            var mutableSet = set
            mutableSet.makeUnique()

            self._storage = mutableSet._elementStorage
            self._index = 0
            self._count = _storage.header

            _storage.header = 0
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _index < _count else { return nil }
            let element = _storage._moveElement(at: _index)
            _index += 1
            return element
        }

        deinit {
            let remaining = _count - _index
            guard remaining > 0 else { return }
            _storage._deinitializeElements(from: _index, count: remaining)
        }
    }
}

// MARK: - Sendable

extension Set_Primitives_Core.Set.Ordered.Bounded.Consuming.Iterator: @unchecked Sendable where Element: Sendable {}
