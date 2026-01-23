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

extension Set_Primitives_Core.Set.Ordered.Small.Consuming {
    /// An iterator that consumes elements from a small ordered set.
    ///
    /// `Iterator` is `~Copyable` because it represents exclusive ownership
    /// over the set's elements. Each call to ``next()`` moves an element out
    /// of the set's storage.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// func process(nodes: consuming Set<Node>.Ordered.Small<4>) {
    ///     var iterator = nodes.makeConsumingIterator()
    ///     while let node = iterator.next() {
    ///         // node is owned, can be moved or consumed
    ///     }
    /// }
    /// ```
    ///
    /// ## Partial Consumption
    ///
    /// If iteration stops early, remaining elements are properly deinitialized
    /// when the iterator is destroyed.
    ///
    /// ## Storage Mode
    ///
    /// The iterator handles both inline and heap-spilled storage transparently.
    @safe
    public struct Iterator: ~Copyable {
        /// Inline storage (used when set hasn't spilled to heap).
        @usableFromInline
        var inlineElements: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Heap storage (used when set has spilled).
        @usableFromInline
        let heapStorage: Set_Primitives_Core.Set<Element>.Ordered.ElementStorage?

        @usableFromInline
        var index: Int

        @usableFromInline
        let count: Int

        /// Whether we're iterating from heap storage.
        @usableFromInline
        let isSpilled: Bool

        @usableFromInline
        init(_consuming set: consuming Set_Primitives_Core.Set<Element>.Ordered.Small<inlineCapacity>) {
            let count = set.storedCount
            let isSpilled = set.heapStorage != nil

            self.count = count
            self.index = 0
            self.isSpilled = isSpilled

            if isSpilled {
                // Heap mode: take the heap storage
                self.heapStorage = set.heapStorage
                self.inlineElements = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))

                // Mark heap storage as empty so its deinit won't double-free
                set.heapStorage!.header = 0
            } else {
                // Inline mode: copy inline storage
                self.inlineElements = set.inlineElements
                self.heapStorage = nil
            }

            // Zero out the set's count to prevent its deinit from double-freeing
            set.storedCount = 0
        }

        @inlinable
        public mutating func next() -> Element? {
            guard index < count else { return nil }

            let element: Element
            if isSpilled {
                // Heap mode
                element = heapStorage!.moveElement(at: index)
            } else {
                // Inline mode
                let stride = MemoryLayout<Element>.stride
                element = unsafe Swift.withUnsafeMutablePointer(to: &inlineElements) { storagePtr in
                    let basePtr = UnsafeMutableRawPointer(storagePtr)
                    let elementPtr = unsafe (basePtr + index * stride).assumingMemoryBound(to: Element.self)
                    return unsafe elementPtr.move()
                }
            }
            index += 1
            return element
        }

        deinit {
            let remaining = count - index
            guard remaining > 0 else { return }

            if isSpilled {
                // Heap mode: deinitialize remaining elements in heap storage
                heapStorage!.deinitializeElements(from: index, count: remaining)
            } else {
                // Inline mode: deinitialize remaining elements in inline storage
                let stride = MemoryLayout<Element>.stride
                unsafe Swift.withUnsafeBytes(of: inlineElements) { bytes in
                    let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for i in index..<count {
                        let elementPtr = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                        unsafe elementPtr.deinitialize(count: 1)
                    }
                }
            }
        }
    }
}

// MARK: - Sendable

extension Set_Primitives_Core.Set.Ordered.Small.Consuming.Iterator: @unchecked Sendable where Element: Sendable {}
