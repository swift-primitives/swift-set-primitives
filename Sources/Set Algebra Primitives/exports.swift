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

// Set Algebra Primitives owns the orthogonal set *algebra* — the relational
// predicates (`where Self: Set.Protocol & Iterable`) and the constructive ops
// (`where Self: Set.Buildable.Protocol & Iterable`, returning `Self`). It is
// the lone set-primitives target that depends on the iteration concern
// (`Iterable`); the membership core stays iteration-free. Re-exports the core +
// the buildable refinement + `Iterable` so the algebra surface is self-contained.

@_exported public import Set_Protocol_Primitives
@_exported public import Set_Buildable_Protocol_Primitives
@_exported public import Iterable
