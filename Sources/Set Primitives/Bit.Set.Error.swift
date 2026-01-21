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

public import Bit_Primitives

// MARK: - Hoisted Error Types
//
// Error types are hoisted to module level for typed throws compatibility.
// Use the typealias (e.g., `Bit.Set.Error`) in your code.

/// Errors that can occur during `Bit.Set` operations.
public enum __BitSetError: Swift.Error, Sendable, Equatable {
    case bounds(index: Int, capacity: Int)
    case invalidCapacity
}

/// Errors that can occur during `Bit.Set.Bounded` operations.
public enum __BitSetBoundedError: Swift.Error, Sendable, Equatable {
    case bounds(index: Int, capacity: Int)
    case invalidCapacity
    case overflow
}

/// Errors that can occur during `Bit.Set.Inline` operations.
public enum __BitSetInlineError: Swift.Error, Sendable, Equatable {
    case bounds(index: Int, capacity: Int)
    case overflow
}

// MARK: - Canonical Error Typealiases

extension Bit.Set {
    /// Errors that can occur during bit set operations.
    public typealias Error = __BitSetError
}

extension Bit.Set.Bounded {
    /// Errors that can occur during bounded bit set operations.
    public typealias Error = __BitSetBoundedError
}

extension Bit.Set.Inline {
    /// Errors that can occur during inline bit set operations.
    public typealias Error = __BitSetInlineError
}
