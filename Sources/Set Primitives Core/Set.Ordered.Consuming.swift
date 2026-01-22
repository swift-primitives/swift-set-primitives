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
// MARK: - Consuming Iteration Namespace
// ===----------------------------------------------------------------------===//
//
// ## Purpose
//
// Provides consuming iteration for ordered sets, enabling ownership transfer
// of elements during iteration. This is the principally correct pattern for
// functions that destructively process a set.
//
// ## API
//
// ```swift
// func process(nodes: consuming Set<Node>.Ordered) {
//     var iterator = nodes.makeConsumingIterator()
//     while let node = iterator.next() {
//         // node is consumed (owned)
//     }
// }
// ```
//
// Or with forEach:
//
// ```swift
// func process(nodes: consuming Set<Node>.Ordered) {
//     nodes.consumingForEach { node in
//         // node is consumed (owned)
//     }
// }
// ```
//
// ## Relationship to drain()
//
// - `drain(_ body:)`: mutating, empties set, keeps variable
// - `consumingForEach(_ body:)`: consuming, relinquishes set ownership
//
// Both are valid and serve different use cases.
//
// ===----------------------------------------------------------------------===//

extension Set_Primitives_Core.Set.Ordered {
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

extension Set_Primitives_Core.Set.Ordered {
    /// Returns an iterator that consumes the set's elements.
    ///
    /// The returned iterator takes ownership of the set's storage and yields
    /// elements by moving them out. This is the principally correct pattern
    /// for functions that receive a set with `consuming` ownership.
    ///
    /// ```swift
    /// func process(nodes: consuming Set<Node>.Ordered) {
    ///     var iterator = nodes.makeConsumingIterator()
    ///     while let node = iterator.next() {
    ///         // Process each node (owned)
    ///     }
    /// }
    /// ```
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
    /// This is useful when you need to reserve capacity before iterating:
    ///
    /// ```swift
    /// func collect(nodes: consuming Set<Node>.Ordered) -> [Node] {
    ///     var counted = nodes.consumingCount()
    ///     var result = [Node]()
    ///     result.reserveCapacity(counted.count)
    ///
    ///     while let node = counted.iterator.next() {
    ///         result.append(node)
    ///     }
    ///     return result
    /// }
    /// ```
    ///
    /// - Complexity: O(1).
    /// - Note: Tuples cannot contain `~Copyable` elements in Swift 6.2,
    ///   so this returns a ``Consuming/Counted`` struct instead.
    @inlinable
    public consuming func consumingCount() -> Consuming.Counted {
        let count = _elementStorage.header
        return Consuming.Counted(count: count, iterator: Consuming.Iterator(_consuming: self))
    }

    /// Iterates over elements, consuming each.
    ///
    /// Unlike ``drain(_:)`` which is `mutating`, this method is `consuming`
    /// and relinquishes ownership of the entire set.
    ///
    /// ```swift
    /// func process(nodes: consuming Set<Node>.Ordered) {
    ///     nodes.consumingForEach { node in
    ///         // node is consumed (owned)
    ///     }
    ///     // nodes is no longer accessible
    /// }
    /// ```
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
