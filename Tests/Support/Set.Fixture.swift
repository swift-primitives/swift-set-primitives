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

public import Set_Primitives
public import Iterator_Chunk_Primitives

extension Set where Element: Hash.`Protocol` & Copyable {
    /// A minimal `Set.Protocol` + `Iterable` conformer for exercising the
    /// membership core's `isEmpty` derivation and the orthogonal relational
    /// predicate algebra (`isDisjoint`, `isSubset`, `isSuperset`,
    /// `isStrictSubset`, `isStrictSuperset`, `isEqual`) — which now compose
    /// `where Self: Iterable` in `Set Algebra Primitives`.
    ///
    /// The fixture owns no storage discipline of its own — it backs onto a
    /// plain array and enforces uniqueness on construction. It exists solely so
    /// the protocol-level behavioural surface has a concrete conformer to test
    /// against, independent of the storage disciplines that live in sibling
    /// packages.
    public struct Fixture {
        @usableFromInline
        let elements: [Element]

        /// Creates a fixture from `elements`, dropping any later duplicates so
        /// the set-uniqueness invariant holds.
        @inlinable
        public init(_ elements: some Sequence<Element>) {
            var unique: [Element] = []
            for element in elements where !unique.contains(where: { $0 == element }) {
                unique.append(element)
            }
            self.elements = unique
        }
    }
}

// MARK: - Membership core ({contains, count})

extension Set.Fixture: Set.`Protocol` where Element: Hash.`Protocol` & Copyable {
    @inlinable
    public func contains(_ element: borrowing Element) -> Bool {
        let needle = copy element
        return elements.contains(where: { $0 == needle })
    }

    @inlinable
    public var count: Index<Element>.Count {
        Index<Element>.Count(Cardinal(Swift.UInt(elements.count)))
    }
}

// MARK: - Iteration concern (so the orthogonal predicate algebra applies)
//
// Reuses the canonical span iterator `Iterator.Chunk` — the same
// `Iterable.Iterator` the storage disciplines vend — over the backing array's
// span, rather than a hand-rolled iterator, so the fixture's iteration matches
// production exactly. `Iterator.Chunk`'s scalar `next()` is the Copyable-element
// default on `Iterator.Chunk.Protocol`.

extension Set.Fixture: Iterable where Element: Hash.`Protocol` & Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Chunk_Primitives.Iterator.Chunk<Element>

    @_lifetime(borrow self)
    @inlinable
    public borrowing func makeIterator() -> Iterator_Chunk_Primitives.Iterator.Chunk<Element> {
        Iterator_Chunk_Primitives.Iterator.Chunk(elements.span)
    }
}
