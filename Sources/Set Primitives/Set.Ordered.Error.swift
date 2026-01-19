// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Set.Ordered {
    /// Typed error for ordered set operations.
    ///
    /// Uses typed throws (`throws(Ordered.Error)`) for compile-time exhaustiveness.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// An index was out of bounds.
        case bounds(Bounds)

        /// An operation was attempted on an empty set.
        case empty(Empty)
    }
}

// MARK: - Error Payloads

extension Set.Ordered.Error {
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

// MARK: - CustomStringConvertible

extension Set.Ordered.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bounds(let e): return "index \(e.index) out of bounds for count \(e.count)"
        case .empty: return "operation attempted on empty ordered set"
        }
    }
}
