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

extension Set where S: ~Copyable {
    /// Type-safe index for set elements.
    ///
    /// Uses `Index<Element>` to provide compile-time safety preventing
    /// cross-collection index confusion.
    ///
    /// ## Ordering
    ///
    /// The base `Set` namespace makes no promise about the order in which
    /// positions enumerate elements. Any ordering guarantee — such as the
    /// insertion-order semantics of the ordered-set discipline — is the
    /// responsibility of the concrete storage discipline that adopts it
    /// (`Set.Ordered` and its capacity variants in `swift-set-ordered-primitives`).
    public typealias Index = Index_Primitives.Index<S.Element>
}
