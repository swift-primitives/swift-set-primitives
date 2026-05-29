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

// Umbrella per [MOD-005]. Re-export every sub-target so a single
// `import Set_Primitives` surfaces the whole package. Set Protocol Primitives
// transitively re-exports Hash_Primitives + Index_Primitives.
//
// NB: the set algebra (predicates + constructive) lifted to the sibling package
// swift-set-algebra-primitives. Its re-export is DELIBERATELY NOT here — that
// package deps swift-set-primitives, so re-exporting it would complete a
// package-level cycle ([MOD-032]/[MOD-033] cursor-pilot drop). Consumers needing
// the algebra (e.g. swift-set-ordered-primitives) dep + re-export
// Set_Algebra_Primitives themselves.

@_exported public import Set_Primitive
@_exported public import Set_Protocol_Primitives
@_exported public import Set_Buildable_Protocol_Primitives
