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
        public var buffer: Buffer<Element>.Linear

        /// Hash table for O(1) position lookup.
        public var hashTable: Hash.Table<Element>

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
            public var buffer: Buffer<Element>.Linear.Bounded

            /// Hash table for O(1) position lookup.
            public var hashTable: Hash.Table<Element>

            /// The maximum number of elements the set can hold.
            public let maximumCapacity: Index_Primitives.Index<Element>.Count

            /// Creates a Fixed ordered set with the specified capacity.
            @inlinable
            public init(capacity: Index_Primitives.Index<Element>.Count) throws(__SetOrderedFixedError) {
                self.buffer = Buffer<Element>.Linear.Bounded(minimumCapacity: capacity)
                self.hashTable = Hash.Table<Element>(minimumCapacity: capacity)
                self.maximumCapacity = capacity
            }
        }

        // MARK: - Static (Fixed-Capacity, Inline Storage)

        /// A fixed-capacity, inline-storage ordered set with compile-time capacity.
        ///
        /// Composes `Buffer<Element>.Linear.Inline<capacity>` for element storage and
        /// `Hash.Table<Element>.Static<capacity>` for O(1) position lookup.
        ///
        /// - Precondition: `capacity` must be a power of two (required by Hash.Table.Static).
        ///
        /// - Note: This type is declared inside `Ordered` (not in an extension) due to a
        ///   Swift compiler bug where nested types with value generic parameters declared
        ///   in extensions do not properly inherit `~Copyable` constraints from the outer type.
        public struct Static<let capacity: Int>: ~Copyable {
            /// Element storage using Buffer.Linear.Inline from buffer-primitives.
            @usableFromInline
            package var _buffer: Buffer<Element>.Linear.Inline<capacity>

            /// Hash table for O(1) position lookup.
            @usableFromInline
            package var _hashTable: Hash.Table<Element>.Static<capacity>

            /// Workaround for Swift compiler bug where deinit element cleanup
            /// fails for ~Copyable structs that contain only value-type properties.
            /// See: https://github.com/swiftlang/swift/issues/86652
            @usableFromInline
            package var _deinitWorkaround: AnyObject? = nil

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
                _buffer.removeAll()
            }
        }

        // MARK: - Small (SmallVec Pattern)

        /// An ordered set with small-buffer optimization (SmallVec pattern).
        @safe
        public struct Small<let inlineCapacity: Int>: ~Copyable {
            @inlinable
            public static var maxElementStride: Int { 64 }

            public var inlineElements: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

            public var storedCount: Index_Primitives.Index<Element>.Count

            public var heapStorage: Storage<Element>?

            public var heapHashTable: Hash.Table<Element>?

            public var _deinitWorkaround: AnyObject? = nil

            /// Creates an empty small ordered set.
            @inlinable
            public init() {
                precondition(
                    MemoryLayout<Element>.stride <= Self.maxElementStride,
                    "Element stride exceeds inline storage slot size"
                )
                self.inlineElements = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
                self.storedCount = .zero
                self.heapStorage = nil
                self.heapHashTable = nil
            }

            deinit {
                let count = storedCount
                guard count > .zero else { return }

                if heapStorage != nil {
                    // Storage deinit handles cleanup via its count property
                    heapStorage!.count = count
                } else {
                    unsafe Swift.withUnsafeBytes(of: inlineElements) { bytes in
                        let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                        var slot: Index_Primitives.Index<Element> = .zero
                        let end = count.map(Ordinal.init)
                        while slot < end {
                            let elementPtr = unsafe basePtr
                                .advanced(by: Index_Primitives.Index<Element>.Offset(fromZero: slot) * .stride)
                                .assumingMemoryBound(to: Element.self)
                            unsafe elementPtr.deinitialize(count: 1)
                            slot += .one
                        }
                    }
                }
            }

            /// Whether the set has spilled to heap storage.
            @inlinable
            public var isSpilled: Bool { heapStorage != nil }
        }
    }
}

// MARK: - Conditional Copyable

extension Set.Ordered: Copyable where Element: Copyable {}
extension Set.Ordered.Fixed: Copyable where Element: Copyable {}

// MARK: - Sendable

extension Set.Ordered: @unchecked Sendable where Element: Sendable {}
extension Set.Ordered.Fixed: @unchecked Sendable where Element: Sendable {}
extension Set.Ordered.Static: @unchecked Sendable where Element: Sendable {}
extension Set.Ordered.Small: @unchecked Sendable where Element: Sendable {}
