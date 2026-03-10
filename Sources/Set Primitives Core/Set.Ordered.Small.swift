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

import Buffer_Linear_Small_Primitives
import Hash_Table_Primitives

extension Set.Ordered where Element: ~Copyable {

    // MARK: - Small (SmallVec Pattern)

    /// An ordered set with small-buffer optimization (SmallVec pattern).
    ///
    /// Composes `Buffer<Element>.Linear.Small<inlineCapacity>` for element storage
    /// and `Hash.Table<Element>` after spill.
    ///
    /// Inline mode uses O(n) linear scan — no hash table overhead for small sizes.
    /// Hash table activates only on spill.
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// Element storage — handles inline/heap dispatch internally.
        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Small<inlineCapacity>

        /// Heap hash table — non-nil after spill.
        @usableFromInline
        package var _heapHashTable: Hash.Table<Element>?

        // WORKAROUND: Forces compiler to execute deinit body.
        // TRACKING: swiftlang/swift #86652 variant (nested ~Copyable deinit chain)
        // WHEN TO REMOVE: When the compiler correctly destroys ~Copyable structs
        //      with cross-package value-generic stored properties.
        private var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty small ordered set.
        @inlinable
        public init() {
            self._buffer = Buffer<Element>.Linear.Small<inlineCapacity>()
            self._heapHashTable = nil
        }

        deinit {
            // WORKAROUND: Manually clean up elements via the mutating path.
            // TRACKING: swiftlang/swift #86652 variant
            unsafe withUnsafePointer(to: _buffer) { ptr in
                unsafe UnsafeMutablePointer(mutating: ptr).pointee.remove.all()
            }
        }

        /// Whether the set has spilled to heap storage.
        @inlinable
        public var isSpilled: Bool { _buffer.isSpilled }
    }
}

// MARK: - Sendable

extension Set.Ordered.Small: @unchecked Sendable where Element: Sendable {}
