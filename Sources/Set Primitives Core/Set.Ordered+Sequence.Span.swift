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

public import Sequence_Primitives

// MARK: - Sequence.Span.Protocol Conformance

extension Set_Primitives_Core.Set.Ordered: Sequence.Span.`Protocol` {
    // span property already exists in Set.Ordered.swift
}

// MARK: - Sequence.Span.Mutable.Protocol Conformance

extension Set_Primitives_Core.Set.Ordered: Sequence.Span.Mutable.`Protocol` where Element: Copyable {
    // mutableSpan property already exists in Set.Ordered.swift
}
