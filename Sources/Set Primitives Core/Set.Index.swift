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

public import Index_Primitives

extension Set {
    /// Type-safe index for ordered set elements.
    ///
    /// Uses `Index<Element>` to provide compile-time safety preventing
    /// cross-collection index confusion.
    ///
    /// ## Position Semantics
    ///
    /// Position 0 is the first element in insertion order.
    /// Position `count - 1` is the most recently inserted element.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let setIdx: Set<Int>.Index = 0
    /// var set = Set<Int>.Ordered()
    /// try set.insert(42)
    /// // Access first element via index
    /// ```
    public typealias Index = Index_Primitives.Index<Element>
}

// MARK: - Typed Subscript (Set.Ordered)

extension Set.Ordered {
    /// Accesses the element at the given typed index in insertion order.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index.position.rawValue` must be in `0..<count`.
    @inlinable
    public subscript(index: Set<Element>.Index) -> Element {
        _read {
            precondition(index.position.rawValue >= 0 && index.position.rawValue < count, "Index out of bounds")
            yield _elementStorage._readElement(at: index.position.rawValue)
        }
    }

    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Set<Element>.Index) -> Element? {
        guard index.position.rawValue >= 0 && index.position.rawValue < count else { return nil }
        return _elementStorage._readElement(at: index.position.rawValue)
    }
}

// MARK: - Bounded Set Index Operations
// NOTE: Per [MEM-COPY-006], Set.Ordered.Bounded extensions are in Set.Ordered.Bounded.swift

// MARK: - Inline Set Index Operations
// NOTE: Per [MEM-COPY-006], Set.Ordered.Inline extensions are in Set.Ordered.Inline.swift
