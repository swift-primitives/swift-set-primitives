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

import Index_Primitives
import Sequence_Primitives
public import Set_Primitives_Core

// MARK: - consume() Implementation
//
// Set.Ordered delegates consuming iteration entirely to Buffer.Linear.
// The buffer owns the full pipeline: State, next closure, and cleanup deinit.
// Set never touches Storage directly.
//
// Pattern: swap buffer with empty, then delegate to buffer.consume().
// After swap, mutableSelf.buffer is empty (destruction harmless).
// consumeBuffer has all elements with unique storage.

extension Set_Primitives_Core.Set.Ordered where Element: Copyable {
    /// Returns a consuming view: `.consume().forEach { }`
    ///
    /// The view takes ownership of the set's elements and provides
    /// `forEach(_:)` for iteration. If iteration is interrupted early,
    /// remaining elements are cleaned up via the buffer's consume state deinit.
    ///
    /// ```swift
    /// let set = Set<Int>.Ordered([1, 2, 3])
    /// set.consume().forEach { element in
    ///     // element is owned
    /// }
    /// // set no longer accessible
    /// ```
    ///
    /// - Complexity: O(1) to create the view. O(1) per element during iteration.
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, Buffer<Element>.Linear.ConsumeState> {
        var mutableSelf = self
        mutableSelf.makeUnique()
        var consumeBuffer = Buffer<Element>.Linear(minimumCapacity: .zero)
        Swift.swap(&mutableSelf.buffer, &consumeBuffer)
        return consumeBuffer.consume()
    }
}
