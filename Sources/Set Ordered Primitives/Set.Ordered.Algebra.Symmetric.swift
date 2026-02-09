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
public import Index_Primitives

extension Set_Primitives_Core.Set.Ordered.Algebra {
    /// Namespace for symmetric set operations.
    ///
    /// Note: This stores the Buffer.Linear (a CoW value type) rather than
    /// the Set.Ordered directly (which would require consuming or mutation).
    public struct Symmetric {
        @usableFromInline
        let buffer: Buffer<Element>.Linear

        @usableFromInline
        init(buffer: Buffer<Element>.Linear) {
            self.buffer = buffer
        }

        @usableFromInline
        var count: Index<Element>.Count { buffer.count }
    }
}

// MARK: - Symmetric Operations

extension Set_Primitives_Core.Set.Ordered.Algebra.Symmetric {
    /// Returns a new set with elements in either set, but not both.
    ///
    /// Elements from `self` come first in their original order,
    /// followed by elements from `other` that are not in `self`.
    ///
    /// - Parameter other: The other set.
    /// - Returns: A new set with elements in exactly one of the sets.
    /// - Complexity: O(n + m) where n and m are the sizes of the sets.
    @inlinable
    public func difference(_ other: borrowing Set_Primitives_Core.Set<Element>.Ordered) -> Set_Primitives_Core.Set<Element>.Ordered {
        var result = Set_Primitives_Core.Set<Element>.Ordered()

        // Elements in self but not in other
        var index: Index<Element> = .zero
        let end = count.map(Ordinal.init)
        while index < end {
            let element = buffer[index]
            if !other.contains(element) {
                result.insert(element)
            }
            index += .one
        }

        // Elements in other but not in self
        var otherIndex: Index<Element> = .zero
        let otherEnd = other.count.map(Ordinal.init)
        while otherIndex < otherEnd {
            let element = other.buffer[otherIndex]
            // Check if element is in self by iterating
            var found = false
            var selfIndex: Index<Element> = .zero
            while selfIndex < end {
                if buffer[selfIndex] == element {
                    found = true
                    break
                }
                selfIndex += .one
            }
            if !found {
                result.insert(element)
            }
            otherIndex += .one
        }

        return result
    }
}
