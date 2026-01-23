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

// MARK: - Sequence.WithSpan.Protocol Conformance

extension Set_Primitives_Core.Set.Ordered.Small: Sequence.WithSpan.`Protocol` {
    // withSpan(_:) method already exists in Set.Ordered.Small.swift
}

// MARK: - Sequence.WithSpan.Mutable.Protocol Conformance

extension Set_Primitives_Core.Set.Ordered.Small: Sequence.WithSpan.Mutable.`Protocol` {
    // withMutableSpan(_:) method already exists in Set.Ordered.Small.swift
}
