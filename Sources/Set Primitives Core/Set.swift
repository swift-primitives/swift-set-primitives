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
/// This shadows `Swift.Set`. Use `Swift.Set` or `Set_Primitives_Core.Set`
/// to disambiguate when both are in scope.
///
/// ## Variants
///
/// - ``Set/Ordered``: Dynamically-growing storage with CoW for Copyable elements
/// - ``Set/Ordered/Bounded``: Fixed-capacity, throws on overflow
/// - ``Set/Ordered/Inline``: Zero-allocation inline storage with compile-time capacity
/// - ``Set/Ordered/Small``: Inline storage with automatic spill to heap (SmallVec pattern)
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
/// ## Conditional Copyable
///
/// Heap-based variants (`Ordered`, `Ordered.Bounded`) are conditionally `Copyable`:
/// when `Element` is `Copyable`, the container is also `Copyable` with copy-on-write
/// semantics.
///
/// Inline-storage variants (`Ordered.Inline`, `Ordered.Small`) are unconditionally
/// `~Copyable` because they require a `deinit` for cleanup. This is a Swift type
/// system limitation, not a design choice—structs with `deinit` cannot be
/// conditionally `Copyable`.
///
/// ```swift
/// // Copyable elements → Copyable container (for heap variants)
/// let a = Set<String>.Ordered()
/// let b = a  // Copy works - both share storage until mutation (CoW)
///
/// // ~Copyable elements → ~Copyable container (all variants)
/// struct Token: ~Copyable, Hash.Protocol { ... }
/// var set = Set<Token>.Ordered()
/// let set2 = set  // Error: cannot copy ~Copyable value
/// ```
public enum Set<Element: Hash.`Protocol` & ~Copyable>: ~Copyable {}
