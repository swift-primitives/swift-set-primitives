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

// Set Primitive declares the hoisted, bound-free carrier `struct __Set<S: ~Copyable>`
// (the insertion-ordered hash-set ADT over an explicit ordered hashed COLUMN,
// [DS-025]) + the canonical front door `Set<E>` ([DS-028]) + the pinned membership
// constructors ([MOD-017]'s zero-dep namespace invariant retired with the enum —
// the Array Primitive precedent; the column packages are ordinary deps). The
// pinned membership surface lives in the umbrella target's `Set+Columns.swift`.
// Per the exports-narrowing ruling (audit #9, 2026-06-10), nothing is re-exported:
// consumers SPELL their column by importing the column-vocabulary modules explicitly.
