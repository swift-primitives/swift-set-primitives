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
// Set.Ordered.Fixed delegates consuming iteration entirely to Buffer.Linear.Bounded.
// Same swap pattern as Set.Ordered — buffer owns the full pipeline.

extension Set_Primitives_Core.Set.Ordered.Fixed where Element: Copyable {
    /// Returns a consuming view: `.consume().forEach { }`
    ///
    /// ```swift
    /// let set = Set<Int>.Ordered.Fixed(capacity: Index<Int>.Count(10))
    /// set.consume().forEach { element in
    ///     // element is owned
    /// }
    /// ```
    ///
    /// - Complexity: O(1) to create the view. O(1) per element during iteration.
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, Buffer<Element>.Linear.Bounded.ConsumeState> {
        var mutableSelf = self
        mutableSelf.makeUnique()
        var consumeBuffer = Buffer<Element>.Linear.Bounded(minimumCapacity: .zero)
        Swift.swap(&mutableSelf.buffer, &consumeBuffer)
        return consumeBuffer.consume()
    }
}
