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

public import Memory_Primitives

// MARK: - Set.Ordered: Memory.Contiguous.Protocol

extension Set_Primitives_Core.Set.Ordered: Memory.Contiguous.`Protocol` {
    // All required methods already implemented in Set.Ordered.swift:
    // - var span: Span<Element>
    // - var mutableSpan: MutableSpan<Element>
    // - func withUnsafeBufferPointer<R, E>(_:) rethrows -> R
    // - mutating func withUnsafeMutableBufferPointer<R, E>(_:) rethrows -> R
}
