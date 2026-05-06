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

public import Set_Primitives_Core

extension Set.Ordered where Element: Copyable {
    /// A result builder for declaratively constructing ordered sets.
    ///
    /// Insertion order is preserved; duplicate elements after the first
    /// occurrence are silently ignored (standard set semantics):
    ///
    /// ```swift
    /// let set = Set<Int>.Ordered {
    ///     1
    ///     2
    ///     2  // duplicate — ignored
    ///     3
    /// }
    /// // Iterates in order: 1, 2, 3
    /// ```
    ///
    /// ## Element Constraint
    ///
    /// Set.Ordered.Builder requires `Element: Copyable` because the
    /// underlying `insert(_:)` operation does not yet support `~Copyable`
    /// elements. ~Copyable element support is a future ecosystem
    /// extension and is out of round-1 scope.
    @resultBuilder
    public enum Builder {

        // MARK: - Expression Building

        @inlinable
        public static func buildExpression(_ expression: Element) -> [Element] {
            [expression]
        }

        @inlinable
        public static func buildExpression(_ expression: [Element]) -> [Element] {
            expression
        }

        @inlinable
        public static func buildExpression(_ expression: Element?) -> [Element] {
            expression.map { [$0] } ?? []
        }

        // MARK: - Partial Block Building

        @inlinable
        public static func buildPartialBlock(first: [Element]) -> [Element] {
            first
        }

        @inlinable
        public static func buildPartialBlock(first: Void) -> [Element] {
            []
        }

        @inlinable
        public static func buildPartialBlock(first: Never) -> [Element] {}

        @inlinable
        public static func buildPartialBlock(
            accumulated: [Element],
            next: [Element]
        ) -> [Element] {
            accumulated + next
        }

        // MARK: - Block Building

        @inlinable
        public static func buildBlock() -> [Element] {
            []
        }

        // MARK: - Control Flow

        @inlinable
        public static func buildOptional(_ component: [Element]?) -> [Element] {
            component ?? []
        }

        @inlinable
        public static func buildEither(first: [Element]) -> [Element] {
            first
        }

        @inlinable
        public static func buildEither(second: [Element]) -> [Element] {
            second
        }

        @inlinable
        public static func buildArray(_ components: [[Element]]) -> [Element] {
            components.flatMap { $0 }
        }

        @inlinable
        public static func buildLimitedAvailability(_ component: [Element]) -> [Element] {
            component
        }
    }
}

// MARK: - Convenience Init

extension Set.Ordered where Element: Copyable {
    /// Constructs an ordered set from a result-builder closure.
    ///
    /// Insertion order is preserved; duplicates after the first occurrence
    /// are ignored.
    ///
    /// ```swift
    /// let set = Set<String>.Ordered {
    ///     "first"
    ///     "second"
    ///     "third"
    /// }
    /// ```
    @inlinable
    public init(@Set.Ordered.Builder _ builder: () -> [Element]) {
        self.init(builder())
    }
}
