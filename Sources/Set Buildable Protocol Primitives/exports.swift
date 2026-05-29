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

// Set Buildable Protocol Primitives owns `Set.Buildable.Protocol` — the
// growable-set refinement of `Set.Protocol`. Re-exports the membership core so
// `Set.Buildable.Protocol`'s `__SetProtocol` requirements are visible.

@_exported public import Set_Protocol_Primitives
