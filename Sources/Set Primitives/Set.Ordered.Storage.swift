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

extension Set.Ordered {
    /// Inlined value-type storage for ordered set.
    ///
    /// Combines a contiguous array for order with a hash table for O(1) lookups.
    /// Uses value semantics - CoW is provided by the underlying `ContiguousArray`
    /// and `Dictionary` types.
    @usableFromInline
    struct Storage {
        /// Elements in insertion order.
        @usableFromInline
        var elements: ContiguousArray<Element>

        /// Maps element to its index in `elements`.
        @usableFromInline
        var indices: [Element: Int]

        @inlinable
        init() {
            self.elements = []
            self.indices = [:]
        }

        @inlinable
        init(elements: ContiguousArray<Element>, indices: [Element: Int]) {
            self.elements = elements
            self.indices = indices
        }
    }
}

// MARK: - Storage Properties

extension Set.Ordered.Storage {
    @inlinable
    var count: Int {
        elements.count
    }

    @inlinable
    var isEmpty: Bool {
        elements.isEmpty
    }

    @inlinable
    var capacity: Int {
        elements.capacity
    }
}

// MARK: - Core Operations

extension Set.Ordered.Storage {
    @inlinable
    func index(_ element: Element) -> Int? {
        indices[element]
    }

    @inlinable
    func contains(_ element: Element) -> Bool {
        indices[element] != nil
    }

    @inlinable
    mutating func insert(_ element: Element) -> (inserted: Bool, index: Int) {
        if let existing = indices[element] {
            return (false, existing)
        }
        let index = elements.count
        elements.append(element)
        indices[element] = index
        return (true, index)
    }

    @inlinable
    mutating func remove(_ element: Element) -> Element? {
        guard let index = indices.removeValue(forKey: element) else {
            return nil
        }
        let removed = elements.remove(at: index)

        // Update indices for shifted elements
        for i in index..<elements.count {
            indices[elements[i]] = i
        }

        return removed
    }
}

// MARK: - Capacity

extension Set.Ordered.Storage {
    @inlinable
    mutating func reserve(_ minimumCapacity: Int) {
        elements.reserveCapacity(minimumCapacity)
        indices.reserveCapacity(minimumCapacity)
    }

    @inlinable
    mutating func clear(keepingCapacity: Bool) {
        if keepingCapacity {
            elements.removeAll(keepingCapacity: true)
            indices.removeAll(keepingCapacity: true)
        } else {
            elements = []
            indices = [:]
        }
    }
}

// MARK: - Sendable

extension Set.Ordered.Storage: Sendable where Element: Sendable {}
