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

extension Set_Primitives_Core.Set.Ordered.Algebra {
    /// Namespace for symmetric set operations.
    ///
    /// Note: This stores the ElementStorage reference (a class, Copyable) rather than
    /// the Set.Ordered directly (which is ~Copyable due to Hash.Table).
    public struct Symmetric {
        @usableFromInline
        let _storage: Set_Primitives_Core.Set<Element>.Ordered.ElementStorage

        @usableFromInline
        init(storage: Set_Primitives_Core.Set<Element>.Ordered.ElementStorage) {
            self._storage = storage
        }

        @usableFromInline
        var _count: Int { _storage.header }
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
        for i in 0..<_count {
            let element = _storage._readElement(at: i)
            if !other.contains(element) {
                result.insert(element)
            }
        }

        // Elements in other but not in self
        for i in 0..<other.count {
            let element = other._elementStorage._readElement(at: i)
            // Check if element is in self by iterating
            var found = false
            for j in 0..<_count {
                if _storage._readElement(at: j) == element {
                    found = true
                    break
                }
            }
            if !found {
                result.insert(element)
            }
        }

        return result
    }
}
