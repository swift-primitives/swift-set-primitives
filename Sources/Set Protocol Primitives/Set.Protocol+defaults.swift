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
public import Index_Primitives

// MARK: - Core Derivation
//
// `isEmpty` is the ONE derivation expressible from the membership core's own
// requirements (`count`) — edge kind (D) in the capability-protocol normal
// form. It needs neither enumeration nor algebra, so it stays on the core
// (`Set Protocol Primitives`). The relational predicates (`isDisjoint`,
// `isSubset`, …) and the constructive algebra (`union`, `intersection`, …) are
// the orthogonal *algebra* concern: they require the iteration concern and live
// in `Set Algebra Primitives`, composed `where Self: Iterable` — never on the
// core's requirements.

extension Set.`Protocol` where Self: ~Copyable {
    /// Whether the set contains no elements.
    @inlinable
    public var isEmpty: Bool { count == .zero }
}
