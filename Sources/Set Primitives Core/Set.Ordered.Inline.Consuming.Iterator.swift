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

extension Set_Primitives_Core.Set.Ordered.Inline.Consuming {
    /// An iterator that consumes elements from an inline ordered set.
    ///
    /// `Iterator` is `~Copyable` because it represents exclusive ownership
    /// over the set's elements. Each call to ``next()`` moves an element out
    /// of the set's storage.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// func process(nodes: consuming Set<Node>.Ordered.Inline<8>) {
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
    @safe
    public struct Iterator: ~Copyable {
        /// The inline storage taken from the set.
        @usableFromInline
        var elements: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        @usableFromInline
        var index: Int

        @usableFromInline
        let count: Int

        @usableFromInline
        init(_consuming set: consuming Set_Primitives_Core.Set<Element>.Ordered.Inline<capacity>) {
            // Capture the count before we zero it out
            let count = set.storedCount

            // Copy the inline storage
            self.elements = set.elements
            self.index = 0
            self.count = count

            // Zero out the set's count to prevent its deinit from double-freeing.
            // We own the elements now; the set's deinit will see count = 0 and skip cleanup.
            set.storedCount = 0
        }

        @inlinable
        public mutating func next() -> Element? {
            guard index < count else { return nil }

            let stride = MemoryLayout<Element>.stride
            let element: Element = unsafe Swift.withUnsafeMutablePointer(to: &elements) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index * stride).assumingMemoryBound(to: Element.self)
                return unsafe elementPtr.move()
            }
            index += 1
            return element
        }

        deinit {
            let remaining = count - index
            guard remaining > 0 else { return }

            let stride = MemoryLayout<Element>.stride
            unsafe Swift.withUnsafeBytes(of: elements) { bytes in
                let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                for i in index..<count {
                    let elementPtr = unsafe (basePtr + i * stride).assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                }
            }
        }
    }
}

// MARK: - Sendable

extension Set_Primitives_Core.Set.Ordered.Inline.Consuming.Iterator: @unchecked Sendable where Element: Sendable {}
