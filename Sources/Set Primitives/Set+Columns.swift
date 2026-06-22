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

// The COLUMN-PINNED membership surface; the `Shared` forms cross the box via the
// gate-first scoped accessors ([MEM-OWN-017]: inserted members thread as consuming
// closure PARAMETERS).
public import Set_Primitive
public import Buffer_Primitive
public import Buffer_Linear_Primitive
public import Storage_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Hash_Indexed_Primitive
import Hash_Table_Primitive
import Hash_Primitives
public import Shared_Primitive
public import Index_Primitives

// ============================================================================
// MARK: - Insert (duplicate hand-back — move-only honesty)
// ============================================================================

extension Set where S: ~Copyable {
    /// Inserts a new member; returns `nil` on success, or hands the element BACK if an
    /// equal member is already present (direct column).
    ///
    /// - Complexity: O(1) amortized
    @inlinable
    @discardableResult
    public mutating func insert<E: Hash.Key & ~Copyable>(_ element: consuming E) -> E?
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear> {
        store.insert(element)
    }

    /// Inserts a new member (`Shared` column; uniqueness restored first).
    ///
    /// - Complexity: O(1) amortized (O(`capacity`) when a copy must be made first)
    @inlinable
    @discardableResult
    public mutating func insert<E: Hash.Key & ~Copyable>(_ element: consuming E) -> E?
    where S == Shared<E, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>> {
        store.withUnique(consuming: element) { column, element in
            column.insert(element)
        }
    }
}

// ============================================================================
// MARK: - Membership
// ============================================================================

extension Set where S: ~Copyable {
    /// Whether an equal member is present (direct column).
    ///
    /// - Complexity: O(1) average
    @inlinable
    public func contains<E: Hash.Key & ~Copyable>(_ element: borrowing E) -> Bool
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear> {
        store.contains(element)
    }

    /// Whether an equal member is present (`Shared` column; no gate — reads never detach).
    ///
    /// - Complexity: O(1) average
    @inlinable
    public func contains<E: Hash.Key & ~Copyable>(_ element: borrowing E) -> Bool
    where S == Shared<E, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>> {
        store.withColumn { $0.contains(element) }
    }
}

// ============================================================================
// MARK: - Remove (insertion order preserved)
// ============================================================================

extension Set where S: ~Copyable {
    /// Removes the equal member; returns it, or `nil` if absent (direct column).
    ///
    /// - Complexity: O(n) from the removal point (order preservation)
    @inlinable
    public mutating func remove<E: Hash.Key & ~Copyable>(_ element: borrowing E) -> E?
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear> {
        store.remove(element)
    }

    /// Removes the equal member (`Shared` column; uniqueness restored first).
    @inlinable
    public mutating func remove<E: Hash.Key & ~Copyable>(_ element: borrowing E) -> E?
    where S == Shared<E, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>> {
        store.withUnique { $0.remove(element) }
    }

    /// Removes all members (direct column).
    @inlinable
    public mutating func removeAll<E: Hash.Key & ~Copyable>(keepingCapacity: Bool = true)
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear> {
        store.removeAll(keepingCapacity: keepingCapacity)
    }

    /// Removes all members (`Shared` column; detaches first — siblings keep theirs).
    @inlinable
    public mutating func removeAll<E: Hash.Key & SendableMetatype>(keepingCapacity: Bool = true)
    where S == Shared<E, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>> {
        let capacity: Index_Primitives.Index<E>.Count = keepingCapacity ? store.capacity : .zero
        self.store = Shared(
            Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>(minimumCapacity: capacity)
        )
    }
}

// ============================================================================
// MARK: - Iteration (insertion order) + direct clone
// ============================================================================

extension Set where S: ~Copyable {
    /// Calls the closure for each member, in insertion order (direct column).
    ///
    /// - Complexity: O(n)
    @inlinable
    public func forEach<E: Hash.Key & ~Copyable>(_ body: (borrowing E) -> Void)
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear> {
        store.forEach(body)
    }

    /// Calls the closure for each member (`Shared` column; no gate).
    ///
    /// - Complexity: O(n)
    @inlinable
    public func forEach<E: Hash.Key & ~Copyable>(_ body: (borrowing E) -> Void)
    where S == Shared<E, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>> {
        store.withColumn { $0.forEach(body) }
    }

    /// Returns an independent copy (direct column).
    ///
    /// - Complexity: O(`capacity`)
    @inlinable
    public func clone<E: Hash.Key>() -> Self
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear> {
        Self(store: store.clone())
    }
}
