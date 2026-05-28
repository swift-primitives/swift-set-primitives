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

public import Set_Primitive
public import Index_Primitives

extension Set {
    /// Type-safe index for ordered set elements.
    ///
    /// Uses `Index<Element>` to provide compile-time safety preventing
    /// cross-collection index confusion.
    ///
    /// ## Position Semantics
    ///
    /// Position 0 is the first element in insertion order.
    /// The last position is the most recently inserted element.
    public typealias Index = Index_Primitives.Index<Element>
}
