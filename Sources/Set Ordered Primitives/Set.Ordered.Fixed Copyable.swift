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

import Cardinal_Primitives
import Index_Primitives
internal import Ordinal_Primitives
public import Set_Primitives_Core

// ============================================================================
// MARK: - Iterator
// ============================================================================

extension Set.Ordered.Fixed where Element: Copyable {
    /// Iterator for Set.Ordered.Fixed that delegates to Buffer.Linear.Bounded.Iterator.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        var _inner: Buffer<Element>.Linear.Bounded.Iterator

        @usableFromInline
        init(_inner: Buffer<Element>.Linear.Bounded.Iterator) {
            self._inner = _inner
        }

        @_lifetime(&self)
        @inlinable
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            _inner.nextSpan(maximumCount: maximumCount)
        }

        @inlinable
        public mutating func next() -> Element? {
            _inner.next()
        }
    }
}

extension Set.Ordered.Fixed.Iterator: @unsafe @unchecked Sendable where Element: Sendable {}

// ============================================================================
// MARK: - Swift.Sequence Conformance
// ============================================================================

extension Set.Ordered.Fixed: Swift.Sequence where Element: Copyable {
    /// Returns an iterator over the elements of the set.
    ///
    /// Elements are yielded in insertion order.
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_inner: buffer.makeIterator())
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
    /// This enables `.forEach.consuming { }` pattern via `Property.Inout` extension.
    @inlinable
    public mutating func removeAll() {
        clear(keepingCapacity: false)
    }
}

// ============================================================================
// MARK: - Set.Protocol Conformance
// ============================================================================

extension Set.Ordered.Fixed: Set.`Protocol` {}

// ============================================================================
// MARK: - ExpressibleByArrayLiteral
// ============================================================================

extension Set.Ordered.Fixed: ExpressibleByArrayLiteral where Element: Copyable {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self = try! Self(capacity: .init(Cardinal(UInt(elements.count))))
        for element in elements {
            try! insert(element)
        }
    }
}
