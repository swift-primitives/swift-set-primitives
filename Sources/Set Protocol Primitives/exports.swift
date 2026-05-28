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

// Set Protocol Primitives owns `Set.Protocol` (membership-uniqueness
// contract), `Set.Index`, and the relational defaults. Re-exports the root
// namespace + its external dependencies so the umbrella surfaces them.

@_exported public import Set_Primitive
@_exported public import Hash_Primitives
@_exported public import Index_Primitives
