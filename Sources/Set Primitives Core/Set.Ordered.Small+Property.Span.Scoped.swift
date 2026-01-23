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

public import Property_Primitives

// MARK: - Property.Span.Scoped.Protocol Conformance

extension Set_Primitives_Core.Set.Ordered.Small: __PropertySpanScopedProtocol {
    // withSpan(_:) method already exists in Set.Ordered.Small.swift
}

// MARK: - Property.Span.Scoped.Mutable.Protocol Conformance

extension Set_Primitives_Core.Set.Ordered.Small: __PropertySpanScopedMutableProtocol {
    // withMutableSpan(_:) method already exists in Set.Ordered.Small.swift
}
