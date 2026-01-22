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

// MARK: - Note on Collection Conformances
//
// Swift's collection protocols (Sequence, Collection, BidirectionalCollection,
// RandomAccessCollection) all require Copyable conformance.
//
// Since Set.Ordered is now unconditionally ~Copyable (to enable first-class
// support for move-only elements and Hash.Table storage), these conformances
// are no longer possible.
//
// Instead, use:
// - `forEach()` for iteration
// - `makeIterator()` for manual iteration
// - Index-based access via subscript `set[index]`
// - `span` property for contiguous read access
//
// This is a fundamental limitation of Swift's protocol system that requires
// Copyable for collection protocols.
