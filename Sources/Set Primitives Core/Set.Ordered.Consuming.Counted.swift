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

extension Set_Primitives_Core.Set.Ordered.Consuming {
    /// A wrapper providing both element count and consuming iterator.
    ///
    /// This type exists because Swift 6.2 does not support tuples containing
    /// `~Copyable` elements. Instead of returning `(count: Int, iterator: Iterator)`,
    /// ``Set/Ordered/consumingCount()`` returns this struct.
    ///
    /// ## Usage
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
    /// ## Design Note
    ///
    /// When Swift gains support for `~Copyable` elements in tuples, this type
    /// may be deprecated in favor of returning a tuple directly.
    @safe
    public struct Counted: ~Copyable {
        /// The number of elements available for iteration.
        public let count: Int

        /// The consuming iterator.
        ///
        /// Use this to iterate over elements after checking/using `count`:
        ///
        /// ```swift
        /// var counted = set.consumingCount()
        /// array.reserveCapacity(counted.count)
        /// while let element = counted.iterator.next() { ... }
        /// ```
        public var iterator: Iterator

        /// Creates a counted iterator wrapper.
        ///
        /// - Parameters:
        ///   - count: The number of elements.
        ///   - iterator: The consuming iterator.
        @usableFromInline
        init(count: Int, iterator: consuming Iterator) {
            self.count = count
            self.iterator = iterator
        }
    }
}

// MARK: - Sendable

extension Set_Primitives_Core.Set.Ordered.Consuming.Counted: @unchecked Sendable where Element: Sendable {}
