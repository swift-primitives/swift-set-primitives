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

// MARK: - Consume Namespace

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Namespace for consuming iteration types.
    ///
    /// Use the `.consume().forEach { }` pattern:
    ///
    /// ```swift
    /// let set = Set<Int>.Ordered.Static<8>([1, 2, 3])
    /// set.consume().forEach { element in
    ///     // element is owned, set is consumed
    /// }
    /// ```
    public enum Consume: ~Copyable {}
}

// MARK: - Consume State

extension Set_Primitives_Core.Set.Ordered.Static.Consume {
    /// State for consuming iteration over inline storage.
    @safe
    public struct State: ~Copyable {
        /// The inline storage taken from the set.
        @usableFromInline
        var elements: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        @usableFromInline
        var index: Int

        @usableFromInline
        let count: Int

        @usableFromInline
        init(elements: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>, count: Int) {
            self.elements = elements
            self.index = 0
            self.count = count
        }

        deinit {
            let remaining = count - index
            guard remaining > 0 else { return }

            let stride = MemoryLayout<Element>.stride
            unsafe Swift.withUnsafeBytes(of: elements) { bytes in
                let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                for i in index..<count {
                    let elementPtr = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                }
            }
        }
    }
}

// MARK: - Sendable

extension Set_Primitives_Core.Set.Ordered.Static.Consume.State: @unchecked Sendable where Element: Sendable {}

// MARK: - consume() Implementation

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Returns a consuming view: `.consume().forEach { }`
    ///
    /// ```swift
    /// let set = Set<Int>.Ordered.Static<8>([1, 2, 3])
    /// set.consume().forEach { element in
    ///     // element is owned
    /// }
    /// ```
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, Consume.State> {
        let count = storedCount

        let state = Consume.State(
            elements: elements,
            count: count
        )

        // Zero out count to prevent set's deinit from double-freeing
        storedCount = 0

        return Sequence.Consume.View(
            state: state,
            next: { state in
                guard state.index < state.count else { return nil }

                let stride = MemoryLayout<Element>.stride
                let element: Element = unsafe Swift.withUnsafeMutablePointer(to: &state.elements) { storagePtr in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe (basePtr + state.index * stride).assumingMemoryBound(to: Element.self)
                    return unsafe elementPtr.move()
                }
                state.index += 1
                return element
            }
        )
    }
}
