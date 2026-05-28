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

/// Namespace for set types supporting move-only elements.
///
/// This shadows `Swift.Set`. Use `Swift.Set` or `Set_Primitive.Set`
/// to disambiguate when both are in scope.
///
/// ## Disciplines
///
/// The ordered-set discipline (`Set.Ordered` and its `.Fixed` / `.Static` /
/// `.Small` capacity variants) lives in the sibling package
/// `swift-set-ordered-primitives` (module `Set_Ordered_Primitives`), which
/// extends this namespace. Import that module to use ordered sets.
///
/// The base unordered/hash `Set` discipline will live in this namespace.
///
/// ## ~Copyable Support
///
/// Unlike `Swift.Set`, set disciplines in this ecosystem support `~Copyable`
/// elements.
///
/// ## Element constraints
///
/// The namespace itself constrains `Element: ~Copyable` only. Set's
/// uniqueness invariant requires `Element: Hash.Protocol`; that constraint
/// lives on `Set.Protocol` (in `Set_Protocol_Primitives`) and on per-variant
/// declarations in sibling packages — not on the namespace — so this target
/// satisfies `[MOD-017]`'s zero-external-dependency invariant.
public enum Set<Element: ~Copyable>: ~Copyable {}
