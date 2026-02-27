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

// ============================================================================
// MARK: - Iterator
// ============================================================================

extension Set.Ordered.Fixed where Element: Copyable {
    /// Iterator for Set.Ordered.Fixed that copies elements for safe iteration.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        var index: Index<Element>

        @usableFromInline
        let buffer: Buffer<Element>.Linear.Bounded

        @usableFromInline
        let count: Index<Element>.Count

        @usableFromInline
        var _spanBuffer: [Element] = []

        @usableFromInline
        init(_ fixed: borrowing Set.Ordered.Fixed) {
            self.index = .zero
            self.buffer = fixed.buffer
            self.count = fixed.buffer.count
        }

        @_lifetime(&self)
        @inlinable
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            _spanBuffer.removeAll(keepingCapacity: true)
            var remaining = Int(maximumCount.rawValue)
            while remaining > 0, index < count {
                _spanBuffer.append(buffer[index])
                index += .one
                remaining -= 1
            }
            return _spanBuffer.span
        }

        @_lifetime(self: immortal)
        @inlinable
        public mutating func next() -> Element? {
            guard index < count else { return nil }
            let element = buffer[index]
            index += .one
            return element
        }
    }
}

extension Set.Ordered.Fixed.Iterator: @unchecked Sendable where Element: Sendable {}

// ============================================================================
// MARK: - Swift.Sequence Conformance
// ============================================================================

extension Set.Ordered.Fixed: Swift.Sequence where Element: Copyable {
    /// Returns an iterator over the elements of the set.
    ///
    /// Elements are yielded in insertion order.
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(self)
    }
}

// ============================================================================
// MARK: - Sequence.Protocol Conformance
// ============================================================================

extension Set.Ordered.Fixed: Sequence.`Protocol` where Element: Copyable {
    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// ============================================================================
// MARK: - Sequence.Clearable Conformance
// ============================================================================

extension Set.Ordered.Fixed: Sequence.Clearable where Element: Copyable {
    /// Removes all elements from the set.
    ///
    /// The capacity remains unchanged.
    /// This enables `.forEach.consuming { }` pattern via `Property.View` extension.
    @inlinable
    public mutating func removeAll() {
        clear(keepingCapacity: false)
    }
}
