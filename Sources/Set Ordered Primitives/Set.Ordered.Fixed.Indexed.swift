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
import Index_Primitives
import Ordinal_Primitives
import Cardinal_Primitives

// MARK: - Set.Ordered.Fixed.Indexed

extension Set_Primitives_Core.Set.Ordered.Fixed where Element: Copyable {
    /// A wrapper providing phantom-typed index access to Fixed ordered set storage.
    ///
    /// `Indexed<Tag>` wraps a `Set<Element>.Ordered.Fixed` and provides subscript
    /// access via `Index<Tag>` instead of `Index<Element>`, enabling type-safe indexing
    /// where the phantom type differs from the element type.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// enum NodeTag {}
    /// var storage = try Set<Payload>.Ordered.Fixed(capacity: Index<Payload>.Count(10))
    /// try storage.insert(payload)
    ///
    /// var indexed = Set.Ordered.Fixed.Indexed<NodeTag>(storage)
    /// let node: Index<NodeTag> = .zero
    /// indexed[node]  // Access via typed index
    /// guard node < indexed.count else { return }  // Typed bounds check
    /// ```
    ///
    /// ## Type Safety
    ///
    /// The phantom `Tag` type prevents mixing indices from different domains:
    ///
    /// ```swift
    /// enum GraphA {}
    /// enum GraphB {}
    ///
    /// var storageA: Set.Ordered.Fixed.Indexed<GraphA> = ...
    /// let nodeB: Index<GraphB> = .zero
    /// // storageA[nodeB]  // Compile error: cannot convert Index<GraphB> to Index<GraphA>
    /// ```
    ///
    /// ## Design
    ///
    /// This follows the `Property.Typed` pattern: the nested type "smuggles" the
    /// `Tag` generic parameter into scope, allowing typed operations without
    /// requiring protocols (which can't have `~Copyable` associated types).
    public struct Indexed<Tag: Copyable>: Copyable, @unchecked Sendable {
        @usableFromInline
        var _storage: Set_Primitives_Core.Set<Element>.Ordered.Fixed

        /// Creates an indexed wrapper around the given storage.
        ///
        /// - Parameter storage: The Fixed ordered set to wrap.
        @inlinable
        public init(_ storage: consuming Set_Primitives_Core.Set<Element>.Ordered.Fixed) {
            self._storage = storage
        }

        /// The phantom-typed count for bounds checking.
        ///
        /// Use with `Index<Tag>` for typed bounds checks:
        /// ```swift
        /// guard node < indexed.count else { return }
        /// ```
        @inlinable
        public var count: Index_Primitives.Index<Tag>.Count {
            _storage.count.retag(Tag.self)
        }

        /// Accesses the element at the given phantom-typed index.
        ///
        /// - Parameter index: The typed index of the element to access.
        /// - Precondition: `index` must be within bounds.
        @inlinable
        public subscript(index: Index_Primitives.Index<Tag>) -> Element {
            get {
                let elementIndex = index.retag(Element.self)
                precondition(elementIndex < _storage.count, "Index out of bounds")
                return _storage.buffer[elementIndex]
            }
        }
    }
}

// MARK: - Passthrough Properties

extension Set_Primitives_Core.Set.Ordered.Fixed.Indexed where Element: Copyable {
    /// Whether the set is empty.
    @inlinable
    public var isEmpty: Bool { _storage.isEmpty }

    /// The maximum number of elements the set can hold.
    @inlinable
    public var capacity: Index_Primitives.Index<Tag>.Count {
        _storage.capacity.retag(Tag.self)
    }

    /// Whether the set is at full capacity.
    @inlinable
    public var isFull: Bool { _storage.isFull }
}

// MARK: - Membership Operations

extension Set_Primitives_Core.Set.Ordered.Fixed.Indexed where Element: Copyable {
    /// Returns whether the set contains the given element.
    @inlinable
    public func contains(_ element: Element) -> Bool {
        _storage.contains(element)
    }

    /// Returns the typed index of the given element, or `nil` if not present.
    @inlinable
    public func index(_ element: Element) -> Index_Primitives.Index<Tag>? {
        guard let rawIndex = _storage.index(element) else { return nil }
        return rawIndex.retag(Tag.self)
    }
}

// MARK: - Mutating Operations

extension Set_Primitives_Core.Set.Ordered.Fixed.Indexed where Element: Copyable {
    /// Inserts an element into the set.
    ///
    /// - Parameter element: The element to insert.
    /// - Returns: A tuple indicating whether insertion occurred and the element's typed index.
    /// - Throws: ``Error/overflow`` if the set is full.
    @inlinable
    @discardableResult
    public mutating func insert(_ element: Element) throws(__SetOrderedFixedError) -> (inserted: Bool, index: Index_Primitives.Index<Tag>) {
        let result = try _storage.insert(element)
        return (result.inserted, result.index.retag(Tag.self))
    }

    /// Removes an element from the set.
    ///
    /// - Parameter element: The element to remove.
    /// - Returns: The removed element, or `nil` if not present.
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        _storage.remove(element)
    }

    /// Removes all elements from the set.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        _storage.clear(keepingCapacity: keepingCapacity)
    }
}

// MARK: - First/Last Accessors

extension Set_Primitives_Core.Set.Ordered.Fixed.Indexed where Element: Copyable {
    /// The first element, or `nil` if the set is empty.
    @inlinable
    public var first: Element? { _storage.first }

    /// The last element, or `nil` if the set is empty.
    @inlinable
    public var last: Element? { _storage.last }
}
