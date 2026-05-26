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

public import Hash_Primitives

/// Namespace for set types supporting move-only elements.
///
/// This shadows `Swift.Set`. Use `Swift.Set` or `Set_Primitives_Core.Set`
/// to disambiguate when both are in scope.
///
/// ## Disciplines
///
/// The ordered-set discipline (`Set.Ordered` and its `.Fixed` / `.Static` /
/// `.Small` capacity variants) lives in the sibling package
/// `swift-set-ordered-primitives` (module `Set_Ordered_Primitives`), which
/// extends this namespace. Import that module to use ordered sets.
///
// future: base unordered/hash Set discipline lives here
///
/// ## ~Copyable Support
///
/// Unlike `Swift.Set`, set disciplines in this ecosystem support `~Copyable`
/// elements.
public enum Set<Element: Hash.`Protocol` & ~Copyable>: ~Copyable {}
