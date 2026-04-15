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

/// Namespace for ordered set types supporting move-only elements.
///
/// This shadows `Swift.Set`. Use `Swift.Set` or `Set_Primitives_Core.Set`
/// to disambiguate when both are in scope.
///
/// ## Variants
///
/// - ``Set/Ordered``: Dynamically-growing storage with CoW for Copyable elements
/// - ``Set/Ordered/Fixed``: Fixed-capacity, throws on overflow
/// - ``Set/Ordered/Inline``: Zero-allocation inline storage with compile-time capacity
/// - ``Set/Ordered/Small``: Inline storage with automatic spill to heap (SmallVec pattern)
///
/// ## ~Copyable Support
///
/// Unlike `Swift.Set`, this implementation supports `~Copyable` elements.
///
/// ## Conditional Copyable
///
/// Heap-based variants (`Ordered`, `Ordered.Fixed`) are conditionally `Copyable`:
/// when `Element` is `Copyable`, the container is also `Copyable` with copy-on-write
/// semantics.
///
/// Inline-storage variants (`Ordered.Static`, `Ordered.Small`) are unconditionally
/// `~Copyable` because they require a `deinit` for cleanup.
public enum Set<Element: Hash.`Protocol` & ~Copyable>: ~Copyable {

    // MARK: - Ordered (Dynamically-Growing, Heap-Allocated)

    /// An ordered set that preserves insertion order with O(1) membership testing.
    ///
    /// Composes `Buffer<Element>.Linear` for element storage and
    /// `Hash.Table<Element>` for O(1) position lookup.
    @safe
    public struct Ordered {

        // MARK: - Stored Properties

        /// Element storage using Buffer.Linear from buffer-primitives.
        @usableFromInline
        package var buffer: Buffer<Element>.Linear

        /// Hash table for O(1) position lookup.
        @usableFromInline
        package var hashTable: Hash.Table<Element>

        // MARK: - Initialization

        /// Creates an empty ordered set.
        @inlinable
        public init() {
            self.buffer = Buffer<Element>.Linear(minimumCapacity: .zero)
            self.hashTable = Hash.Table<Element>(minimumCapacity: .zero)
        }

        // MARK: - Fixed (Fixed-Capacity, Heap-Allocated)

        /// A fixed-capacity ordered set that throws on overflow.
        ///
        /// Composes `Buffer<Element>.Linear.Bounded` for element storage and
        /// `Hash.Table<Element>` for O(1) position lookup.
        @safe
        public struct Fixed {
            /// Element storage using Buffer.Linear.Bounded from buffer-primitives.
            @usableFromInline
            package var buffer: Buffer<Element>.Linear.Bounded

            /// Hash table for O(1) position lookup.
            @usableFromInline
            package var hashTable: Hash.Table<Element>

            /// The maximum number of elements the set can hold.
            public let maximumCapacity: Index_Primitives.Index<Element>.Count

            /// Creates a Fixed ordered set with the specified capacity.
            @inlinable
            public init(capacity: Index_Primitives.Index<Element>.Count) throws(__SetOrderedFixedError<Element>) {
                self.buffer = Buffer<Element>.Linear.Bounded(minimumCapacity: capacity)
                self.hashTable = Hash.Table<Element>(minimumCapacity: capacity)
                self.maximumCapacity = capacity
            }
        }

    }
}

// MARK: - Conditional Copyable

extension Set.Ordered: Copyable where Element: Copyable {}
extension Set.Ordered.Fixed: Copyable where Element: Copyable {}

// MARK: - Sendable

extension Set.Ordered: @unsafe @unchecked Sendable where Element: Sendable {}
extension Set.Ordered.Fixed: @unsafe @unchecked Sendable where Element: Sendable {}
