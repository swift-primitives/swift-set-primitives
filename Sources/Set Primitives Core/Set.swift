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

/// Namespace for ordered set types supporting move-only elements.
///
/// This shadows `Swift.Set`. Use `Swift.Set` or module-qualified
/// `Set_Primitives_Core.Set` to disambiguate when both are in scope.
///
/// ## ~Copyable Support
///
/// Unlike `Swift.Set`, this implementation supports `~Copyable` elements:
///
/// ```swift
/// struct Token: ~Copyable, Hash.Protocol { ... }
/// var set = Set<Token>.Ordered()
/// set.insert(Token(1))  // consumes the token
/// ```
///
/// The set container itself is also `~Copyable` for variants that require
/// custom deinitializers (Inline, Small).
public enum Set<Element: Hash.`Protocol` & ~Copyable>: ~Copyable {}
