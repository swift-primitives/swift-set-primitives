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

// MARK: - Consume Namespace

extension Set_Primitives_Core.Set.Ordered.Bounded {
    /// Namespace for consuming iteration types.
    ///
    /// Use the `.consume().forEach { }` pattern:
    ///
    /// ```swift
    /// let set = Set<Int>.Ordered.Bounded([1, 2, 3], capacity: 10)
    /// set.consume().forEach { element in
    ///     // element is owned, set is consumed
    /// }
    /// ```
    public enum Consume: ~Copyable {}
}

// MARK: - Consume State

extension Set_Primitives_Core.Set.Ordered.Bounded.Consume {
    /// State for consuming iteration.
    @safe
    public struct State: ~Copyable {
        @usableFromInline
        let storage: Set_Primitives_Core.Set<Element>.Ordered.ElementStorage

        @usableFromInline
        var index: Int

        @usableFromInline
        let count: Int

        @usableFromInline
        init(storage: Set_Primitives_Core.Set<Element>.Ordered.ElementStorage, count: Int) {
            self.storage = storage
            self.index = 0
            self.count = count
        }

        deinit {
            let remaining = count - index
            if remaining > 0 {
                storage.deinitializeElements(from: index, count: remaining)
            }
        }
    }
}

// MARK: - Sendable

extension Set_Primitives_Core.Set.Ordered.Bounded.Consume.State: @unchecked Sendable where Element: Sendable {}

// MARK: - consume() Implementation

extension Set_Primitives_Core.Set.Ordered.Bounded {
    /// Returns a consuming view: `.consume().forEach { }`
    ///
    /// ```swift
    /// let set = Set<Int>.Ordered.Bounded([1, 2, 3], capacity: 10)
    /// set.consume().forEach { element in
    ///     // element is owned
    /// }
    /// ```
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, Consume.State> {
        var mutableSelf = self
        mutableSelf.makeUnique()

        let count = mutableSelf.elementStorage.header

        let state = Consume.State(
            storage: mutableSelf.elementStorage,
            count: count
        )

        mutableSelf.elementStorage.header = 0

        return Sequence.Consume.View(
            state: state,
            next: { state in
                guard state.index < state.count else { return nil }
                let element = state.storage.moveElement(at: state.index)
                state.index += 1
                return element
            }
        )
    }
}
