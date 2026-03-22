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

import Buffer_Linear_Inline_Primitives
import Hash_Table_Primitives

extension Set.Ordered where Element: ~Copyable {

    // MARK: - Static (Fixed-Capacity, Inline Storage)

    /// A fixed-capacity, inline-storage ordered set with compile-time capacity.
    ///
    /// Composes `Buffer<Element>.Linear.Inline<capacity>` for element storage and
    /// `Hash.Table<Element>.Static<capacity>` for O(1) position lookup.
    ///
    /// - Precondition: `capacity` must be a power of two (required by Hash.Table.Static).
    public struct Static<let capacity: Int>: ~Copyable {
        // WORKAROUND: swiftlang/swift#86652 — @_rawLayout triviality misclassification.
        // Forces compiler to recognize type as non-trivially destructible so deinit executes.
        // COST: 8 bytes overhead per instance.
        // REMOVAL TEST: swift-buffer-primitives/Experiments/rawlayout-access-level-trigger/
        //   Build with `public` access under -O. If it passes, remove this field
        //   and the manual cleanup in deinit.
        // TRACKING: swift-buffer-primitives/Research/rawlayout-release-crash-investigation.md
        //
        // NOTE: Must be declared BEFORE _buffer. The buffer transitively
        // contains @_rawLayout storage which must be last in memory layout.
        // See Storage.Inline for the Swift 6.2.4 IRGen crash details.
        private var _deinitWorkaround: AnyObject? = nil

        /// Element storage using Buffer.Linear.Inline from buffer-primitives.
        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Inline<capacity>

        /// Hash table for O(1) position lookup.
        @usableFromInline
        package var _hashTable: Hash.Table<Element>.Static<capacity>

        /// Creates an empty inline ordered set.
        ///
        /// - Precondition: `capacity` must be a power of two.
        @inlinable
        public init() {
            self._buffer = Buffer<Element>.Linear.Inline<capacity>()
            // Hash.Table.Static.init() validates power-of-two capacity
            self._hashTable = Hash.Table<Element>.Static<capacity>()
        }

        deinit {
            // WORKAROUND: Manually clean up elements via the mutating path.
            // TRACKING: swiftlang/swift #86652 variant
            unsafe withUnsafePointer(to: _buffer) { ptr in
                unsafe UnsafeMutablePointer(mutating: ptr).pointee.remove.all()
            }
        }
    }
}

// MARK: - Sendable

extension Set.Ordered.Static: @unchecked Sendable where Element: Sendable {}
