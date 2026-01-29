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

extension Set_Primitives_Core.Set.Ordered {
    /// Namespace for consuming iteration types.
    ///
    /// Types in this namespace enable consuming iteration where elements
    /// are moved out of the set and the set is destroyed.
    ///
    /// Use the `.consume().forEach { }` pattern:
    ///
    /// ```swift
    /// let set = Set<Int>.Ordered([1, 2, 3])
    /// set.consume().forEach { element in
    ///     // element is owned, set is consumed
    /// }
    /// // set no longer accessible
    /// ```
    public enum Consume: ~Copyable {}
}

// MARK: - Consume State

extension Set_Primitives_Core.Set.Ordered.Consume {
    /// State for consuming iteration.
    ///
    /// Holds iteration state and provides cleanup via deinit.
    /// All iteration LOGIC is in `Sequence.Consume.View` (from sequence-primitives).
    /// This struct only holds DATA and provides cleanup.
    ///
    /// ## Cleanup
    ///
    /// If iteration stops early (e.g., via `break` or early return), remaining
    /// elements are properly deinitialized when this state is destroyed.
    @safe
    public struct State: ~Copyable {
        /// The element storage taken from the set.
        @usableFromInline
        let storage: Storage<Element>

        /// Current position in the storage.
        @usableFromInline
        var index: Index<Element>

        /// Total number of elements (captured at creation).
        @usableFromInline
        let count: Index<Element>.Count

        /// Creates iteration state from the set's storage.
        @usableFromInline
        init(storage: Storage<Element>, count: Index<Element>.Count) {
            self.storage = storage
            self.index = .zero
            self.count = count
        }

        /// Cleanup: deinitialize any elements not consumed.
        /// Called automatically when View goes out of scope.
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

extension Set_Primitives_Core.Set.Ordered.Consume.State: @unchecked Sendable where Element: Sendable {}

// MARK: - consume() Implementation
//
// Note: Protocol conformance to Sequence.Consume.Protocol is not possible
// due to SE-0427 (associated types cannot be ~Copyable). The consume() method
// follows the protocol pattern and conformance can be added when Swift lifts
// this restriction.

extension Set_Primitives_Core.Set.Ordered where Element: Copyable {
    /// Returns a consuming view: `.consume().forEach { }`
    ///
    /// The view takes ownership of the set's elements and provides
    /// `forEach(_:)` for iteration. If iteration is interrupted early,
    /// remaining elements are cleaned up via the state's deinit.
    ///
    /// ```swift
    /// let set = Set<Int>.Ordered([1, 2, 3])
    /// set.consume().forEach { element in
    ///     // element is owned
    /// }
    /// // set no longer accessible
    /// ```
    ///
    /// - Complexity: O(1) to create the view.
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, Consume.State> {
        // Ensure unique ownership of storage before consuming.
        // This is necessary because the set may share storage with copies.
        var mutableSelf = self
        mutableSelf.makeUnique()

        let count = mutableSelf.elementStorage.count

        // Create state with storage ownership
        let state = Consume.State(
            storage: mutableSelf.elementStorage,
            count: count
        )

        // Mark storage as empty so its deinit won't double-free elements.
        // The State's deinit takes responsibility for cleanup.
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
