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
    /// A wrapper providing both element count and consuming iterator.
    ///
    /// This type exists because Swift 6.2 does not support tuples containing
    /// `~Copyable` elements.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// func collect(nodes: consuming Set<Node>.Ordered.Bounded) -> [Node] {
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
    @safe
    public struct Counted: ~Copyable {
        /// The number of elements available for iteration.
        public let count: Int

        /// The consuming iterator.
        public var iterator: Iterator

        @usableFromInline
        init(count: Int, iterator: consuming Iterator) {
            self.count = count
            self.iterator = iterator
        }
    }
}

// MARK: - Sendable

extension Set_Primitives_Core.Set.Ordered.Bounded.Consuming.Counted: @unchecked Sendable where Element: Sendable {}
