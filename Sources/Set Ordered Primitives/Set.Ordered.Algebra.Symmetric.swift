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
public import Storage_Primitives
public import Index_Primitives

extension Set_Primitives_Core.Set.Ordered.Algebra {
    /// Namespace for symmetric set operations.
    ///
    /// Note: This stores the Storage reference (a class, Copyable) rather than
    /// the Set.Ordered directly (which is ~Copyable due to Hash.Table).
    public struct Symmetric {
        @usableFromInline
        let storage: Storage_Primitives.Storage<Element>

        @usableFromInline
        init(storage: Storage_Primitives.Storage<Element>) {
            self.storage = storage
        }

        @usableFromInline
        var count: Index<Element>.Count { storage.count }
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
        _ = unsafe storage.withUnsafeMutablePointerToElements { selfElements in
            for index in Index<Element>.zero..<count {
                let element = unsafe selfElements[index]
                if !other.contains(element) {
                    result.insert(element)
                }
            }
        }

        // Elements in other but not in self
        _ = unsafe other.elementStorage.withUnsafeMutablePointerToElements { otherElements in
            unsafe storage.withUnsafeMutablePointerToElements { selfElements in
                for otherIndex in Index<Element>.zero..<other.count {
                    let element = unsafe otherElements[otherIndex]
                    // Check if element is in self by iterating
                    var found = false
                    for selfIndex in Index<Element>.zero..<count {
                        if unsafe selfElements[selfIndex] == element {
                            found = true
                            break
                        }
                    }
                    if !found {
                        result.insert(element)
                    }
                }
            }
        }

        return result
    }
}
