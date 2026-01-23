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

// MARK: - Property.Span.Protocol Conformance

extension Set_Primitives_Core.Set.Ordered: __PropertySpanProtocol {
    // span property already exists in Set.Ordered.swift
}

// MARK: - Property.Span.Mutable.Protocol Conformance

extension Set_Primitives_Core.Set.Ordered: __PropertySpanMutableProtocol where Element: Copyable {
    // mutableSpan property already exists in Set.Ordered.swift
}
