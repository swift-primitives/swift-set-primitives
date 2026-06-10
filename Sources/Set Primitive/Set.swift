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

public import Buffer_Primitive
public import Buffer_Linear_Primitive
public import Buffer_Protocol_Primitives
public import Store_Protocol_Primitives
public import Storage_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Hash_Indexed_Primitive
import Hash_Table_Primitive
import Hash_Primitives
public import Shared_Primitive
public import Index_Primitives

// MARK: - Set (the ADT tier — generic over the ORDERED HASHED column)

/// An insertion-ordered hash set — the semantic ADT over an explicit ORDERED HASHED
/// storage COLUMN (the base `Set` the namespace always promised, built at the
/// ADT-families tranche, 2026-06-10).
///
/// The ratified two-column design: `Set` is generic over `S`, and **copyability flows
/// from the column** (S5):
///
/// ```swift
/// Set<            Hash.Indexed<Buffer<Storage<…System>.Contiguous<FD >>.Linear>>   // zero-cost MOVE-ONLY (default)
/// Set<Shared<Int, Hash.Indexed<Buffer<Storage<…System>.Contiguous<Int>>.Linear>>>  // explicit CoW value semantics
/// ```
///
/// The column is `Hash.Indexed<Dense>`: members live DENSELY in insertion order; the
/// hash side is the bucket position-index engine (tombstone-free backward shift,
/// per-instance seed). `Shared` wraps the COMPOSITE — one box, one clone strategy.
/// Iteration (`forEach`) is insertion-ordered. Members never mutate in place
/// (mutability ruling (a)): the surface is insert / contains / remove.
///
/// This shadows `Swift.Set`. Use `Swift.Set` for the stdlib type when both are in scope.
///
/// The ordered-set discipline (`Set.Ordered` and its variants, sibling package) and the
/// set algebra reshape onto this column vocabulary at their own W5 rounds.
@frozen
public struct Set<S: Store.`Protocol` & Buffer.`Protocol` & ~Copyable>: ~Copyable
where S.Count == Index_Primitives.Index<S.Element>.Count, S.Element: Hash.Key {

    /// The ordered hashed column — move-only (the default ownership column) or a
    /// `Shared` CoW column. The ADT is a thin membership discipline over it; it
    /// carries NO deinit.
    @usableFromInline
    package var store: S

    /// Wraps an existing column.
    @inlinable
    public init(store: consuming S) {
        self.store = store
    }

    /// Consumes the set, yielding its storage column.
    @inlinable
    public consuming func take() -> S {
        store
    }
}

// MARK: - Conditional Conformances (co-located per [COPY-FIX-004])

/// The S5 chain: `Set<Shared<E, B>>` is `Copyable` exactly when the ELEMENT is.
extension Set: Copyable where S: Copyable {}

extension Set: Sendable where S: Sendable & ~Copyable {}

// MARK: - Column-pinned construction ([MEM-COPY-017]: the split lives in `Shared`'s
// pinned constructor pair; the `Set` forms pick the column)

extension Set where S: ~Copyable {
    /// Creates an empty MOVE-ONLY set (the default ownership column).
    @inlinable
    public init<E: Hash.Key & ~Copyable>(minimumCapacity: Index_Primitives.Index<E>.Count = .zero)
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear> {
        self.init(store: S(minimumCapacity: minimumCapacity))
    }

    /// Creates an empty CoW (value-semantic) set on the `Shared` column.
    @inlinable
    public init<E: Hash.Key & SendableMetatype>(minimumCapacity: Index_Primitives.Index<E>.Count = .zero)
    where S == Shared<E, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear>> {
        self.init(store: Shared(
            Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear>(minimumCapacity: minimumCapacity)
        ))
    }

    /// Creates an empty statically-unique set of move-only members on the `Shared`
    /// column (the boxed flavor of the move-only regime).
    @inlinable
    public init<E: Hash.Key & SendableMetatype & ~Copyable>(minimumCapacity: Index_Primitives.Index<E>.Count = .zero)
    where S == Shared<E, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear>> {
        self.init(store: Shared(
            Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear>(minimumCapacity: minimumCapacity)
        ))
    }
}
