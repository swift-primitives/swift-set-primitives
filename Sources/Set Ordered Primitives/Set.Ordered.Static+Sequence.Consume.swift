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

import Sequence_Primitives
public import Set_Primitives_Core

// MARK: - consume() Implementation
//
// Set.Ordered.Static delegates consuming iteration to Buffer.Linear.Inline.
// Direct delegation — no swap needed because Inline.consume() is mutating,
// leaving the buffer empty so the set's deinit (which calls _buffer.removeAll())
// is harmless.

extension Set_Primitives_Core.Set.Ordered.Static {
    /// Returns a consuming view: `.consume().forEach { }`
    ///
    /// ```swift
    /// let set = Set<Int>.Ordered.Static<8>([1, 2, 3])
    /// set.consume().forEach { element in
    ///     // element is owned
    /// }
    /// ```
    ///
    /// - Complexity: O(n) to create the view (element transfer). O(1) per element during iteration.
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, Buffer<Element>.Linear.Inline<capacity>.ConsumeState> {
        return _buffer.consume()
        // _buffer is now empty; deinit calls _buffer.removeAll() — no-op
    }
}
