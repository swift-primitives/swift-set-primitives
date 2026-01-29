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
public import Bit_Primitives

// MARK: - Relation Accessor

extension Set<Bit>.Packed.Inline {
    /// Nested accessor for set relation operations.
    ///
    /// ```swift
    /// if a.relation.isSubset(of: b) { ... }
    /// if a.relation.isSuperset(of: b) { ... }
    /// if a.relation.isDisjoint(with: b) { ... }
    /// ```
    @inlinable
    public var relation: Relation {
        Relation(storage: storage)
    }
}

// MARK: - Relation Type

extension Set<Bit>.Packed.Inline {
    /// Namespace for set relation operations.
    public struct Relation: Sendable {
        @usableFromInline
        let storage: InlineArray<wordCount, UInt>

        @usableFromInline
        init(storage: InlineArray<wordCount, UInt>) {
            self.storage = storage
        }
    }
}

// MARK: - Relation Operations

extension Set<Bit>.Packed.Inline.Relation {
    /// Returns whether this set is a subset of another.
    ///
    /// - Parameter other: The potential superset.
    /// - Returns: `true` if every element in this set is also in `other`.
    @inlinable
    public func isSubset(of other: Set<Bit>.Packed.Inline<wordCount>) -> Bool {
        for i in 0..<wordCount {
            if (storage[i] & ~other.storage[i]) != 0 {
                return false
            }
        }
        return true
    }

    /// Returns whether this set is a superset of another.
    ///
    /// - Parameter other: The potential subset.
    /// - Returns: `true` if every element in `other` is also in this set.
    @inlinable
    public func isSuperset(of other: Set<Bit>.Packed.Inline<wordCount>) -> Bool {
        other.relation.isSubset(of: Set<Bit>.Packed.Inline<wordCount>(__storage: storage))
    }

    /// Returns whether this set is disjoint from another.
    ///
    /// - Parameter other: The other set.
    /// - Returns: `true` if the sets have no elements in common.
    @inlinable
    public func isDisjoint(with other: Set<Bit>.Packed.Inline<wordCount>) -> Bool {
        for i in 0..<wordCount {
            if (storage[i] & other.storage[i]) != 0 {
                return false
            }
        }
        return true
    }
}
