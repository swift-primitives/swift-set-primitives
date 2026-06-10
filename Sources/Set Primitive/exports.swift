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

// Set Primitive declares the base type: the column-generic `struct Set<S>`
// template ([MOD-017]'s zero-dep namespace invariant retired with the enum —
// the Array Primitive precedent; the column packages are ordinary deps). The
// pinned membership surface lives in the umbrella target's `Set+Columns.swift`.
