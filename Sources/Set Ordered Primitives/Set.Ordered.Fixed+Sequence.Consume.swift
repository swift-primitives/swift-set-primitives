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
public import Sequence_Primitives
public import Index_Primitives

// MARK: - Consume Namespace

extension Set_Primitives_Core.Set.Ordered.Fixed {
    /// Namespace for consuming iteration types.
    ///
    /// Use the `.consume().forEach { }` pattern:
    ///
    /// ```swift
    /// let set = Set<Int>.Ordered.Fixed(capacity: Index<Int>.Count(10))
    /// set.consume().forEach { element in
    ///     // element is owned, set is consumed
    /// }
    /// ```
    public enum Consume: ~Copyable {}
}

// MARK: - Consume State

extension Set_Primitives_Core.Set.Ordered.Fixed.Consume {
    /// State for consuming iteration.
    @safe
    public struct State: ~Copyable {
        @usableFromInline
        let storage: Storage<Element>

        @usableFromInline
        var index: Index<Element>

        @usableFromInline
        let count: Index<Element>.Count

        @usableFromInline
        init(storage: Storage<Element>, count: Index<Element>.Count) {
            self.storage = storage
            self.index = .zero
            self.count = count
        }

        deinit {
            guard index < count else { return }
            let indexInt = Int(bitPattern: index.position.rawValue)
            let countInt = Int(bitPattern: count)
            let remaining = countInt - indexInt
            if remaining > 0 {
                _ = unsafe storage.withUnsafeMutablePointerToElements { elements in
                    for i in indexInt..<countInt {
                        unsafe (elements + i).deinitialize(count: 1)
                    }
                }
            }
        }
    }
}

// MARK: - Sendable

extension Set_Primitives_Core.Set.Ordered.Fixed.Consume.State: @unchecked Sendable where Element: Sendable {}

// MARK: - consume() Implementation

extension Set_Primitives_Core.Set.Ordered.Fixed where Element: Copyable {
    /// Returns a consuming view: `.consume().forEach { }`
    ///
    /// ```swift
    /// let set = Set<Int>.Ordered.Fixed(capacity: Index<Int>.Count(10))
    /// set.consume().forEach { element in
    ///     // element is owned
    /// }
    /// ```
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, Consume.State> {
        var mutableSelf = self
        mutableSelf.makeUnique()

        let count = mutableSelf.elementStorage.count

        let state = Consume.State(
            storage: mutableSelf.elementStorage,
            count: count
        )

        mutableSelf.elementStorage.count = .zero

        return Sequence.Consume.View(
            state: state,
            next: { state in
                guard state.index < state.count else { return nil }
                let element = state.storage.move(at: state.index)
                state.index = Index<Element>(__unchecked: (), Ordinal(state.index.position.rawValue + 1))
                return element
            }
        )
    }
}
