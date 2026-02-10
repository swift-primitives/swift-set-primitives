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

import Index_Primitives

// ===----------------------------------------------------------------------===//
// MARK: - Hoisted Error Types
// ===----------------------------------------------------------------------===//
//
// Swift does not allow nested types inside generic types to be easily accessed.
// These error types are hoisted to module level and exposed via typealiases.

/// Hoisted implementation of ``Set/Ordered/Error``.
public enum __SetOrderedError<Element: Hash.`Protocol` & ~Copyable>: Swift.Error, Sendable, Equatable {
    /// An index was out of bounds.
    case bounds(Bounds)

    /// An operation was attempted on an empty set.
    case empty(Empty)

    /// Bounds violation payload.
    public struct Bounds: Sendable, Equatable {
        public let index: Index_Primitives.Index<Element>
        public let count: Index_Primitives.Index<Element>.Count

        @inlinable
        public init(index: Index_Primitives.Index<Element>, count: Index_Primitives.Index<Element>.Count) {
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
        case .bounds(let e): return "index \(Int(bitPattern: e.index)) out of bounds for count \(Int(bitPattern: e.count))"
        case .empty: return "operation attempted on empty ordered set"
        }
    }
}

/// Hoisted implementation of ``Set/Ordered/Fixed/Error``.
public enum __SetOrderedFixedError<Element: Hash.`Protocol` & ~Copyable>: Swift.Error, Sendable, Equatable {
    /// The index is out of bounds.
    case bounds(Bounds)

    /// The set is empty.
    case empty(Empty)

    /// The set is full and cannot accept more elements.
    case overflow(Overflow)

    /// The specified capacity is invalid.
    case invalidCapacity(InvalidCapacity)

    /// Bounds violation payload.
    public struct Bounds: Sendable, Equatable {
        public let index: Index_Primitives.Index<Element>
        public let count: Index_Primitives.Index<Element>.Count

        @inlinable
        public init(index: Index_Primitives.Index<Element>, count: Index_Primitives.Index<Element>.Count) {
            self.index = index
            self.count = count
        }
    }

    /// Empty collection payload.
    public struct Empty: Sendable, Equatable {
        @inlinable
        public init() {}
    }

    /// Overflow payload.
    public struct Overflow: Sendable, Equatable {
        @inlinable
        public init() {}
    }

    /// Invalid capacity payload.
    public struct InvalidCapacity: Sendable, Equatable {
        @inlinable
        public init() {}
    }
}

extension __SetOrderedFixedError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bounds(let e):
            return "index \(Int(bitPattern: e.index)) out of bounds for count \(Int(bitPattern: e.count))"
        case .empty:
            return "operation attempted on empty Fixed set"
        case .overflow:
            return "Fixed set is full"
        case .invalidCapacity:
            return "invalid capacity"
        }
    }
}

/// Hoisted implementation of ``Set/Ordered/Inline/Error``.
public enum __SetOrderedInlineError<Element: Hash.`Protocol` & ~Copyable>: Swift.Error, Sendable, Equatable {
    /// The set is full and cannot accept more elements.
    case overflow(Overflow)

    /// The index is out of bounds.
    case bounds(Bounds)

    /// Overflow payload.
    public struct Overflow: Sendable, Equatable {
        @inlinable
        public init() {}
    }

    /// Bounds violation payload.
    public struct Bounds: Sendable, Equatable {
        public let index: Index_Primitives.Index<Element>
        public let count: Index_Primitives.Index<Element>.Count

        @inlinable
        public init(index: Index_Primitives.Index<Element>, count: Index_Primitives.Index<Element>.Count) {
            self.index = index
            self.count = count
        }
    }
}

extension __SetOrderedInlineError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .overflow:
            return "inline set is full"
        case .bounds(let e):
            return "index \(Int(bitPattern: e.index)) out of bounds for count \(Int(bitPattern: e.count))"
        }
    }
}

// MARK: - Error Typealiases

extension Set_Primitives_Core.Set.Ordered {
    /// Errors that can occur during ordered set operations.
    public typealias Error = __SetOrderedError<Element>
}

extension Set_Primitives_Core.Set.Ordered.Fixed {
    /// Errors that can occur during Fixed ordered set operations.
    public typealias Error = __SetOrderedFixedError<Element>
}

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Errors that can occur during inline ordered set operations.
    public typealias Error = __SetOrderedInlineError<Element>
}
