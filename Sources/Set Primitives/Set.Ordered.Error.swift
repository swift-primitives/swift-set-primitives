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

// ===----------------------------------------------------------------------===//
// MARK: - Hoisted Error Types
// ===----------------------------------------------------------------------===//
//
// Swift does not allow nested types inside generic types to be easily accessed.
// These error types are hoisted to module level and exposed via typealiases.

/// Hoisted implementation of ``Set/Ordered/Error``.
public enum __SetOrderedError: Swift.Error, Sendable, Equatable {
    /// An index was out of bounds.
    case bounds(Bounds)

    /// An operation was attempted on an empty set.
    case empty(Empty)

    /// Bounds violation payload.
    public struct Bounds: Sendable, Equatable {
        public let index: Int
        public let count: Int

        @inlinable
        public init(index: Int, count: Int) {
            self.index = index
            self.count = count
        }
    }

    /// Empty collection payload.
    public struct Empty: Sendable, Equatable {
        @inlinable
        public init() {}
    }
}

extension __SetOrderedError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bounds(let e): return "index \(e.index) out of bounds for count \(e.count)"
        case .empty: return "operation attempted on empty ordered set"
        }
    }
}

/// Hoisted implementation of ``Set/Ordered/Bounded/Error``.
public enum __SetOrderedBoundedError: Swift.Error, Sendable, Equatable {
    /// The index is out of bounds.
    case bounds(index: Int, count: Int)

    /// The set is empty.
    case empty

    /// The set is full and cannot accept more elements.
    case overflow

    /// The specified capacity is invalid.
    case invalidCapacity
}

extension __SetOrderedBoundedError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bounds(let index, let count):
            return "index \(index) out of bounds for count \(count)"
        case .empty:
            return "operation attempted on empty bounded set"
        case .overflow:
            return "bounded set is full"
        case .invalidCapacity:
            return "invalid capacity"
        }
    }
}

/// Hoisted implementation of ``Set/Ordered/Inline/Error``.
public enum __SetOrderedInlineError: Swift.Error, Sendable, Equatable {
    /// The set is full and cannot accept more elements.
    case overflow

    /// The index is out of bounds.
    case indexOutOfBounds(index: Int, count: Int)
}

extension __SetOrderedInlineError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .overflow:
            return "inline set is full"
        case .indexOutOfBounds(let index, let count):
            return "index \(index) out of bounds for count \(count)"
        }
    }
}

// MARK: - Error Typealiases

extension Set_Primitives.Set.Ordered {
    /// Errors that can occur during ordered set operations.
    public typealias Error = __SetOrderedError
}

extension Set_Primitives.Set.Ordered.Bounded {
    /// Errors that can occur during bounded ordered set operations.
    public typealias Error = __SetOrderedBoundedError
}

extension Set_Primitives.Set.Ordered.Inline {
    /// Errors that can occur during inline ordered set operations.
    public typealias Error = __SetOrderedInlineError
}
