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
public import Storage_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Hash_Indexed_Primitive

// MARK: - Set<E> — the CANONICAL front door ([DS-028])

/// An insertion-ordered hash set over the default column: the growable, heap-allocated,
/// move-only ordered-hashed column.
///
/// This is the canonical front-door alias ([DS-028]) — the sanctioned
/// [API-NAME-004] generic-instantiation exception that pins the default column so
/// consumers spell `Set<Element>`, never the carrier `__Set` or a full column. The
/// alias fully specializes: conformances, the pinned constructors, and `~Copyable`
/// members all flow through it with zero forwarding and zero runtime cost.
///
/// ```swift
/// var s = Set<Int>()  // growable move-only ordered-hashed set (this alias)
/// ```
///
/// This shadows `Swift.Set`. Use `Swift.Set` for the stdlib type when both are in
/// scope.
///
/// The `Shared` (CoW) variant is consumer-pulled and rides the carrier directly
/// (`__Set<Ownership.Shared<E, …>>`) until it gains a live front-door consumer; the
/// ordered-set discipline is `Set<E>.Ordered` (sibling package, a [DS-028] nest
/// alias on `__Set`).
public typealias Set<E: Hash.Key & ~Copyable> =
    __Set<Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>>
