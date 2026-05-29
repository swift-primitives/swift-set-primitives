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

public import Set_Primitive
public import Set_Protocol_Primitives
public import Index_Primitives

// MARK: - Set.Buildable.Protocol (Hoisted as __SetBuildableProtocol)

/// The constructive refinement of the set membership core: a *growable* set
/// that can be built up element-by-element.
///
/// `Set.Buildable.\`Protocol\`` refines ``Set/`Protocol``` with the two
/// primitives the constructive algebra needs — an empty `init()` and `insert`
/// — so the constructive operations (`union`, `intersection`, `subtracting`,
/// `symmetricDifference`) can be written once as defaults returning **`Self`**
/// (`Set Algebra Primitives`, `where Self: Set.Buildable.\`Protocol\` &
/// Iterable`). Growable disciplines (`Set.Ordered`, `Set.Ordered.Small`)
/// conform; bounded disciplines (`Set.Ordered.Fixed`, `.Static`) do **not** —
/// they inherit the predicates but not the `Self`-returning constructive ops,
/// because a bounded result can overflow.
///
/// ## Hoisted Protocol Pattern
///
/// Per [API-IMPL-009] the protocol is declared at module scope as
/// `__SetBuildableProtocol` and aliased as `Set.Buildable.\`Protocol\``;
/// the declaring module conforms via the hoisted name, consumers via the alias.
public protocol __SetBuildableProtocol: __SetProtocol, ~Copyable {
    /// Creates an empty set.
    init()

    /// Inserts `element`, reporting whether it was newly inserted and its index.
    @discardableResult
    mutating func insert(_ element: consuming Element) -> (inserted: Bool, index: Index<Element>)
}

// MARK: - Namespace Typealias

extension Set where Element: ~Copyable {
    /// Constructive (growable) set namespace — see ``Set/Buildable/`Protocol```.
    public enum Buildable {
        /// The growable-set refinement of ``Set/`Protocol```.
        public typealias `Protocol` = __SetBuildableProtocol
    }
}
