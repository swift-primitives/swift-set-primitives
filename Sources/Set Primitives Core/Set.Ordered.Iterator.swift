//
//  File.swift
//  swift-set-primitives
//
//  Created by Coen ten Thije Boonkkamp on 23/01/2026.
//

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

// MARK: - Conditional Sequence

/// `Set.Ordered` conforms to `Swift.Sequence` when `Element` is `Copyable`.
///
/// This enables `for-in` loops, `map`, `filter`, and other sequence operations.
/// For iteration without Copyable, use ``forEach(_:)`` instead.
extension Set_Primitives_Core.Set.Ordered: Swift.Sequence where Element: Copyable {
    // Note: Iterator is already defined below in the Iterator section.
    // Sequence conformance uses the existing makeIterator() method.
}
