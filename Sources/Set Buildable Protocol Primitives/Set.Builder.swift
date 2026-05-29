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

public import Set_Primitive

extension Set where Element: Copyable {
    /// The family-level result builder for declaratively constructing any set
    /// variant.
    ///
    /// Hoisted from the former per-variant `Set.Ordered.Builder` so `@Set.Builder`
    /// reads right for every variant. It accumulates into `[Element]` (pure
    /// syntax — no storage discipline); a conformer's
    /// ``Set/Buildable/`Protocol``` finalize (`init()` + `insert`) turns that
    /// into the concrete set. Insertion order is preserved; duplicates after the
    /// first occurrence collapse on insert (standard set semantics):
    ///
    /// ```swift
    /// let s = Set<Int>.Ordered { 1; 2; 2; if flag { [3, 5] } }   // growable — free
    /// let t = try Set<Int>.Ordered.Static<8> { 1; 2; 3 }          // bounded — throwing
    /// ```
    ///
    /// ## Element Constraint
    ///
    /// `Set.Builder` requires `Element: Copyable` because it accumulates into a
    /// `[Element]` and the finalize copies elements in via `insert`. `~Copyable`
    /// element support is a future ecosystem extension (out of round-1 scope).
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

        /// Bulk-add a sequence (Range, Set, lazy chain, etc.) without
        /// per-iteration allocation.
        @inlinable
        public static func buildExpression<S: Swift.Sequence>(_ expression: S) -> [Element]
        where S.Element == Element {
            Array(expression)
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
            accumulated: consuming [Element],
            next: [Element]
        ) -> [Element] {
            accumulated.append(contentsOf: next)
            return accumulated
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
