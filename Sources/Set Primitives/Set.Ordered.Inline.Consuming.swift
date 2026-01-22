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

extension Set_Primitives.Set.Ordered.Inline {
    /// Namespace for consuming iteration types.
    ///
    /// Types in this namespace enable consuming iteration where elements
    /// are moved out of the set rather than copied.
    ///
    /// - ``Iterator``: A `~Copyable` iterator that yields elements by moving them.
    /// - ``Counted``: A wrapper providing both element count and iterator.
    public enum Consuming: ~Copyable {}
}

// MARK: - Consuming Methods

extension Set_Primitives.Set.Ordered.Inline {
    /// Returns an iterator that consumes the set's elements.
    ///
    /// The returned iterator takes ownership of the set's storage and yields
    /// elements by moving them out.
    ///
    /// - Complexity: O(1) to create the iterator.
    /// - Note: If iteration stops early, remaining elements are properly
    ///   deinitialized when the iterator is destroyed.
    @inlinable
    public consuming func makeConsumingIterator() -> Consuming.Iterator {
        Consuming.Iterator(_consuming: self)
    }

    /// Returns both the element count and a consuming iterator.
    ///
    /// This is useful when you need to reserve capacity before iterating.
    ///
    /// - Complexity: O(1).
    @inlinable
    public consuming func consumingCount() -> Consuming.Counted {
        let count = _count
        return Consuming.Counted(count: count, iterator: Consuming.Iterator(_consuming: self))
    }

    /// Iterates over elements, consuming each.
    ///
    /// Unlike ``drain(_:)`` which is `mutating`, this method is `consuming`
    /// and relinquishes ownership of the entire set.
    ///
    /// - Parameter body: A closure that receives each consumed element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public consuming func consumingForEach(_ body: (consuming Element) -> Void) {
        var iterator = makeConsumingIterator()
        while let element = iterator.next() {
            body(element)
        }
    }
}
