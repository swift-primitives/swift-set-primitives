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

extension Set<Bit>.Packed {
    /// Nested accessor for set relation operations.
    ///
    /// ```swift
    /// if a.relation.isSubset(of: b) { ... }
    /// if a.relation.isSuperset(of: b) { ... }
    /// if a.relation.isDisjoint(with: b) { ... }
    /// ```
    @inlinable
    public var relation: Relation {
        Relation(storage: storage, capacity: storedCapacity)
    }
}

// MARK: - Relation Type

extension Set<Bit>.Packed {
    /// Namespace for set relation operations.
    public struct Relation: Sendable {
        @usableFromInline
        let storage: ContiguousArray<UInt>

        @usableFromInline
        let capacity: Int

        @usableFromInline
        init(storage: ContiguousArray<UInt>, capacity: Int) {
            self.storage = storage
            self.capacity = capacity
        }
    }
}

// MARK: - Relation Operations

extension Set<Bit>.Packed.Relation {
    /// Returns whether this set is a subset of another.
    ///
    /// - Parameter other: The potential superset.
    /// - Returns: `true` if every element in this set is also in `other`.
    @inlinable
    public func isSubset(of other: Set<Bit>.Packed) -> Bool {
        for i in 0..<storage.count {
            let selfWord = storage[i]
            let otherWord = i < other.storage.count ? other.storage[i] : 0
            if (selfWord & ~otherWord) != 0 {
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
    public func isSuperset(of other: Set<Bit>.Packed) -> Bool {
        other.relation.isSubset(of: Set<Bit>.Packed(__storage: storage, capacity: capacity))
    }

    /// Returns whether this set is disjoint from another.
    ///
    /// - Parameter other: The other set.
    /// - Returns: `true` if the sets have no elements in common.
    @inlinable
    public func isDisjoint(with other: Set<Bit>.Packed) -> Bool {
        let minWords = Swift.min(storage.count, other.storage.count)
        for i in 0..<minWords {
            if (storage[i] & other.storage[i]) != 0 {
                return false
            }
        }
        return true
    }
}
