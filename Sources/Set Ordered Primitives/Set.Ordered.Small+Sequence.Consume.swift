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

// MARK: - consume() Implementation
//
// Set.Ordered.Small delegates consuming iteration to Buffer.Linear.
// Both inline and heap paths produce the same ConsumeState type —
// no mode branching in the iteration hot path.
//
// Inline path: copy elements to a temporary heap buffer, then consume it.
// Heap path: swap out the heap buffer directly, then consume it.

extension Set_Primitives_Core.Set.Ordered.Small where Element: Copyable {
    /// Returns a consuming view: `.consume().forEach { }`
    ///
    /// Both inline and heap storage paths produce a unified
    /// `Buffer<Element>.Linear.ConsumeState` — no dual-mode branching
    /// in the iteration hot path.
    ///
    /// ```swift
    /// let set = Set<Int>.Ordered.Small<4>([1, 2, 3])
    /// set.consume().forEach { element in
    ///     // element is owned, set is consumed
    /// }
    /// ```
    ///
    /// - Complexity: O(n) to create the view (copies inline elements). O(1) per element during iteration.
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, Buffer<Element>.Linear.ConsumeState> {
        var mutableSelf = self
        if mutableSelf.isSpilled {
            // Heap path: extract heap buffer directly
            var consumeBuffer = Buffer<Element>.Linear(minimumCapacity: .zero)
            Swift.swap(&mutableSelf._heapBuffer!, &consumeBuffer)
            mutableSelf._heapHashTable = nil
            return consumeBuffer.consume()
        } else {
            // Inline path: copy to heap buffer, then consume
            var consumeBuffer = Buffer<Element>.Linear(minimumCapacity: mutableSelf._inlineBuffer.count)
            var idx: Index<Element> = .zero
            let end = mutableSelf._inlineBuffer.count.map(Ordinal.init)
            while idx < end {
                consumeBuffer.append(mutableSelf._inlineBuffer[idx])
                idx += .one
            }
            mutableSelf._inlineBuffer.removeAll()
            return consumeBuffer.consume()
        }
    }
}
