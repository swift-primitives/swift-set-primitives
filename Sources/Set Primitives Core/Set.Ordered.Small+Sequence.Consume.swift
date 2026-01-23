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

extension Set_Primitives_Core.Set.Ordered.Small {
    /// Namespace for consuming iteration types.
    ///
    /// Use the `.consume().forEach { }` pattern:
    ///
    /// ```swift
    /// let set = Set<Int>.Ordered.Small<4>([1, 2, 3])
    /// set.consume().forEach { element in
    ///     // element is owned, set is consumed
    /// }
    /// ```
    public enum Consume: ~Copyable {}
}

// MARK: - Consume State

extension Set_Primitives_Core.Set.Ordered.Small.Consume {
    /// State for consuming iteration.
    ///
    /// Handles both inline and heap-spilled storage transparently.
    @safe
    public struct State: ~Copyable {
        /// Inline storage (used when set hasn't spilled to heap).
        @usableFromInline
        var inlineElements: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Heap storage (used when set has spilled).
        @usableFromInline
        let heapStorage: Set_Primitives_Core.Set<Element>.Ordered.ElementStorage?

        @usableFromInline
        var index: Int

        @usableFromInline
        let count: Int

        /// Whether we're iterating from heap storage.
        @usableFromInline
        let isSpilled: Bool

        @usableFromInline
        init(
            inlineElements: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>,
            heapStorage: Set_Primitives_Core.Set<Element>.Ordered.ElementStorage?,
            count: Int,
            isSpilled: Bool
        ) {
            self.inlineElements = inlineElements
            self.heapStorage = heapStorage
            self.index = 0
            self.count = count
            self.isSpilled = isSpilled
        }

        deinit {
            let remaining = count - index
            guard remaining > 0 else { return }

            if isSpilled {
                // Heap mode: deinitialize remaining elements in heap storage
                heapStorage!.deinitializeElements(from: index, count: remaining)
            } else {
                // Inline mode: deinitialize remaining elements in inline storage
                let stride = MemoryLayout<Element>.stride
                unsafe Swift.withUnsafeBytes(of: inlineElements) { bytes in
                    let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for i in index..<count {
                        let elementPtr = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                        unsafe elementPtr.deinitialize(count: 1)
                    }
                }
            }
        }
    }
}

// MARK: - Sendable

extension Set_Primitives_Core.Set.Ordered.Small.Consume.State: @unchecked Sendable where Element: Sendable {}

// MARK: - consume() Implementation

extension Set_Primitives_Core.Set.Ordered.Small {
    /// Returns a consuming view: `.consume().forEach { }`
    ///
    /// ```swift
    /// let set = Set<Int>.Ordered.Small<4>([1, 2, 3])
    /// set.consume().forEach { element in
    ///     // element is owned
    /// }
    /// ```
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, Consume.State> {
        let count = storedCount
        let isSpilled = heapStorage != nil

        let state: Consume.State
        if isSpilled {
            // Heap mode: take the heap storage
            state = Consume.State(
                inlineElements: InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0)),
                heapStorage: heapStorage,
                count: count,
                isSpilled: true
            )
            // Mark heap storage as empty so its deinit won't double-free
            heapStorage!.header = 0
        } else {
            // Inline mode: copy inline storage
            state = Consume.State(
                inlineElements: inlineElements,
                heapStorage: nil,
                count: count,
                isSpilled: false
            )
        }

        // Zero out count to prevent set's deinit from double-freeing
        storedCount = 0

        return Sequence.Consume.View(
            state: state,
            next: { state in
                guard state.index < state.count else { return nil }

                let element: Element
                if state.isSpilled {
                    // Heap mode
                    element = state.heapStorage!.moveElement(at: state.index)
                } else {
                    // Inline mode
                    let stride = MemoryLayout<Element>.stride
                    element = unsafe Swift.withUnsafeMutablePointer(to: &state.inlineElements) { storagePtr in
                        let basePtr = UnsafeMutableRawPointer(storagePtr)
                        let elementPtr = unsafe (basePtr + state.index * stride).assumingMemoryBound(to: Element.self)
                        return unsafe elementPtr.move()
                    }
                }
                state.index += 1
                return element
            }
        )
    }
}
