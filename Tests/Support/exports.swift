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

// Test Support shell ([MOD-024] empty-shell template). The set conformer fixture
// + the relational-default tests moved to swift-set-algebra-primitives with the
// algebra (the Iterable-using surface they exercise), so set-primitives' Test
// Support carries no fixture of its own. Re-exports the umbrella + the Index
// Test Support spine anchor for downstream test consumers.

@_exported public import Set_Primitives
@_exported public import Index_Primitives_Test_Support
