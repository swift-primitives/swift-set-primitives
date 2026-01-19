// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Set.Ordered.Algebra {
    /// Namespace for symmetric set operations.
    public struct Symmetric {
        @usableFromInline
        let set: Set<Element>.Ordered

        @usableFromInline
        init(set: Set<Element>.Ordered) {
            self.set = set
        }
    }
}

// MARK: - Symmetric Operations

extension Set.Ordered.Algebra.Symmetric {
    /// Returns a new set with elements in either set, but not both.
    ///
    /// Elements from `self` come first in their original order,
    /// followed by elements from `other` that are not in `self`.
    ///
    /// - Parameter other: The other set.
    /// - Returns: A new set with elements in exactly one of the sets.
    /// - Complexity: O(n + m) where n and m are the sizes of the sets.
    @inlinable
    public func difference(_ other: Set<Element>.Ordered) -> Set<Element>.Ordered {
        var result = Set<Element>.Ordered()

        // Elements in self but not in other
        for element in set {
            if !other.contains(element) {
                result.insert(element)
            }
        }

        // Elements in other but not in self
        for element in other {
            if !set.contains(element) {
                result.insert(element)
            }
        }

        return result
    }
}
