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
// Use the typealias (e.g., `Set<Bit>.Packed.Error`) in your code.

/// Errors that can occur during `Set<Bit>.Packed` operations.
public enum __SetBitPackedError: Swift.Error, Sendable, Equatable {
    /// The index is out of bounds.
    case bounds(Bounds)

    /// The specified capacity is invalid.
    case invalidCapacity(InvalidCapacity)

    /// Bounds violation payload.
    public struct Bounds: Sendable, Equatable {
        public let index: Int
        public let capacity: Int

        @inlinable
        public init(index: Int, capacity: Int) {
            self.index = index
            self.capacity = capacity
        }
    }

    /// Invalid capacity payload.
    public struct InvalidCapacity: Sendable, Equatable {
        @inlinable
        public init() {}
    }
}

/// Errors that can occur during `Set<Bit>.Packed.Bounded` operations.
public enum __SetBitPackedBoundedError: Swift.Error, Sendable, Equatable {
    /// The index is out of bounds.
    case bounds(Bounds)

    /// The specified capacity is invalid.
    case invalidCapacity(InvalidCapacity)

    /// The set is full and cannot accept more elements.
    case overflow(Overflow)

    /// Bounds violation payload.
    public struct Bounds: Sendable, Equatable {
        public let index: Int
        public let capacity: Int

        @inlinable
        public init(index: Int, capacity: Int) {
            self.index = index
            self.capacity = capacity
        }
    }

    /// Invalid capacity payload.
    public struct InvalidCapacity: Sendable, Equatable {
        @inlinable
        public init() {}
    }

    /// Overflow payload.
    public struct Overflow: Sendable, Equatable {
        @inlinable
        public init() {}
    }
}

/// Errors that can occur during `Set<Bit>.Packed.Inline` operations.
public enum __SetBitPackedInlineError: Swift.Error, Sendable, Equatable {
    /// The index is out of bounds.
    case bounds(Bounds)

    /// The set is full and cannot accept more elements.
    case overflow(Overflow)

    /// Bounds violation payload.
    public struct Bounds: Sendable, Equatable {
        public let index: Int
        public let capacity: Int

        @inlinable
        public init(index: Int, capacity: Int) {
            self.index = index
            self.capacity = capacity
        }
    }

    /// Overflow payload.
    public struct Overflow: Sendable, Equatable {
        @inlinable
        public init() {}
    }
}

/// Errors that can occur during `Set<Bit>.Packed.Small` operations.
public enum __SetBitPackedSmallError: Swift.Error, Sendable, Equatable {
    /// The index is out of bounds.
    case bounds(Bounds)

    /// Bounds violation payload.
    public struct Bounds: Sendable, Equatable {
        public let index: Int
        public let capacity: Int

        @inlinable
        public init(index: Int, capacity: Int) {
            self.index = index
            self.capacity = capacity
        }
    }
}

// MARK: - Canonical Error Typealias

extension Set<Bit>.Packed {
    /// Errors that can occur during packed bit set operations.
    public typealias Error = __SetBitPackedError
}

// Note: Error typealiases for Bounded, Inline, Small are in Set Bit Packed Primitives
// module since those types are declared there.
