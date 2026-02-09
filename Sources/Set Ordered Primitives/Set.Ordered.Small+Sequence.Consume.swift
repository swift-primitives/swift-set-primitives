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
// Set.Ordered.Small delegates consuming iteration to Buffer.Linear.Small.
// The composed buffer handles both inline and heap paths internally.

extension Set_Primitives_Core.Set.Ordered.Small where Element: Copyable {
    /// Returns a consuming view: `.consume().forEach { }`
    ///
    /// Delegates to `Buffer<Element>.Linear.Small.consume()` which handles
    /// both inline and heap storage paths internally.
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
    public consuming func consume() -> Sequence.Consume.View<Element, Buffer<Element>.Linear.Small<inlineCapacity>.ConsumeState> {
        var mutableSelf = self
        mutableSelf._heapHashTable = nil
        return mutableSelf._buffer.consume()
    }
}
