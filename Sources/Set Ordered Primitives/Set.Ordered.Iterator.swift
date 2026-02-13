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
import Index_Primitives
public import Ordinal_Primitives
import Cardinal_Primitives

// MARK: - Iterator (Copyable elements only)

// When Element: Copyable, Set.Ordered conforms to Swift.Sequence, enabling
// for-in loops, map, filter, and other sequence operations.
// For ~Copyable elements, use forEach() or index-based iteration instead.

extension Set_Primitives_Core.Set.Ordered where Element: Copyable {
    /// Iterator for Set.Ordered that copies elements for safe iteration.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        var index: Index<Element>

        @usableFromInline
        let buffer: Buffer<Element>.Linear

        @usableFromInline
        let count: Index<Element>.Count

        @usableFromInline
        init(_ ordered: borrowing Set_Primitives_Core.Set<Element>.Ordered) {
            self.index = .zero
            self.buffer = ordered.buffer
            self.count = buffer.count
        }

        @inlinable
        public mutating func next() -> Element? {
            guard index < count else { return nil }
            let element = buffer[index]
            index += .one
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

// MARK: - Conditional Sequence

/// `Set.Ordered` conforms to `Swift.Sequence` when `Element` is `Copyable`.
///
/// This enables `for-in` loops, `map`, `filter`, and other sequence operations.
/// For iteration without Copyable, use ``forEach(_:)`` instead.
extension Set_Primitives_Core.Set.Ordered: Swift.Sequence where Element: Copyable {
    // Note: Iterator is already defined below in the Iterator section.
    // Sequence conformance uses the existing makeIterator() method.
}
