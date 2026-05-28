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

extension Set where Element: Hash.`Protocol` & Copyable {
    /// A minimal `Set.Protocol`-conforming fixture for exercising the
    /// relational defaults (`isDisjoint`, `isSubset`, `isSuperset`,
    /// `isStrictSubset`, `isStrictSuperset`, `isEmpty`, `isEqual`).
    ///
    /// The fixture owns no storage discipline of its own — it backs onto a
    /// plain array and enforces uniqueness on construction. It exists solely
    /// so the protocol-level behavioural surface declared in
    /// `Set_Protocol_Primitives` has a concrete conformer to test against,
    /// independent of the storage disciplines that live in sibling packages.
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

extension Set.Fixture: Set.`Protocol` where Element: Hash.`Protocol` & Copyable {
    @inlinable
    public func contains(_ element: borrowing Element) -> Bool {
        let needle = copy element
        return elements.contains(where: { $0 == needle })
    }

    @inlinable
    public func forEach<E: Swift.Error>(
        _ body: (borrowing Element) throws(E) -> Void
    ) throws(E) {
        for element in elements {
            try body(element)
        }
    }

    @inlinable
    public var count: Index<Element>.Count {
        Index<Element>.Count(Cardinal(Swift.UInt(elements.count)))
    }
}
