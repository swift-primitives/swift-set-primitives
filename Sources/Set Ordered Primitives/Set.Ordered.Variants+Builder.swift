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

extension Set.Ordered.Static where Element: Copyable {
    /// Constructs a fixed-capacity inline ordered set from a result-builder closure.
    ///
    /// Wraps the dynamic `Set<Element>.Ordered.Builder` per Round-2 Option Y.
    /// Insertion order preserved; duplicates collapse. Overflow throws
    /// `__SetOrderedInlineError`.
    public init(
        @Set<Element>.Ordered.Builder _ builder: () -> [Element]
    ) throws(__SetOrderedInlineError<Element>) {
        let elements = builder()
        self.init()
        for element in elements {
            _ = try self.insert(element)
        }
    }
}

extension Set.Ordered.Small where Element: Copyable {
    /// Constructs a SmallVec ordered set from a result-builder closure.
    ///
    /// Wraps the dynamic `Set<Element>.Ordered.Builder`. Non-throwing
    /// because Small spills inline capacity to the heap.
    public init(
        @Set<Element>.Ordered.Builder _ builder: () -> [Element]
    ) {
        let elements = builder()
        self.init()
        for element in elements {
            _ = self.insert(element)
        }
    }
}

extension Set.Ordered.Fixed where Element: Copyable {
    /// Constructs a heap-allocated bounded ordered set from a result-builder closure.
    ///
    /// Wraps the dynamic `Set<Element>.Ordered.Builder`. Capacity at outer
    /// init; overflow throws.
    public init(
        capacity: Index<Element>.Count,
        @Set<Element>.Ordered.Builder _ builder: () -> [Element]
    ) throws(__SetOrderedFixedError<Element>) {
        var fixed = try Set<Element>.Ordered.Fixed(capacity: capacity)
        let elements = builder()
        for element in elements {
            _ = try fixed.insert(element)
        }
        self = fixed
    }
}
