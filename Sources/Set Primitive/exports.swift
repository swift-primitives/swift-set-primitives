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

// Set Primitive declares the root `enum Set {}`. Zero deps per [MOD-017]'s
// root-target invariant — the singular `Set Primitive` is universally cheap
// to import for sibling packages that only extend the `Set` namespace.
