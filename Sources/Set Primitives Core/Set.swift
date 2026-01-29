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
    @safe
    public struct Ordered {

        // MARK: - Stored Properties

        /// Element storage using the Storage primitive.
        public var elementStorage: Storage<Element>

        /// Hash table for O(1) position lookup.
        public var hashTable: Hash.Table<Element>

        // MARK: - Initialization

        /// Creates an empty ordered set.
        @inlinable
        public init() {
            self.elementStorage = Storage<Element>.create(minimumCapacity: .zero)
            self.hashTable = Hash.Table<Element>(minimumCapacity: .zero)
        }

        // MARK: - Fixed (Fixed-Capacity, Heap-Allocated)

        /// A fixed-capacity ordered set that throws on overflow.
        @safe
        public struct Fixed {
            /// Element storage using the Storage primitive.
            public var elementStorage: Storage<Element>

            /// Hash table for O(1) position lookup.
            public var hashTable: Hash.Table<Element>

            /// The maximum number of elements the set can hold.
            public let maximumCapacity: Index_Primitives.Index<Element>.Count

            /// Creates a Fixed ordered set with the specified capacity.
            @inlinable
            public init(capacity: Index_Primitives.Index<Element>.Count) throws(__SetOrderedFixedError) {
                self.elementStorage = Storage<Element>.create(minimumCapacity: capacity)
                self.hashTable = Hash.Table<Element>(minimumCapacity: capacity)
                self.maximumCapacity = capacity
            }
        }

        // MARK: - Inline (Fixed-Capacity, Inline Storage)

        /// A fixed-capacity, inline-storage ordered set with compile-time capacity.
        public struct Static<let capacity: Int>: ~Copyable {
            @inlinable
            public static var maxElementStride: Int { 64 }

            public var elements: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

            public var storedCount: Int

            public var _deinitWorkaround: AnyObject? = nil

            /// Creates an empty inline ordered set.
            @inlinable
            public init() {
                precondition(
                    MemoryLayout<Element>.stride <= Self.maxElementStride,
                    "Element stride exceeds inline storage slot size"
                )
                self.elements = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
                self.storedCount = 0
            }

            deinit {
                let count = storedCount
                guard count > 0 else { return }

                let stride = MemoryLayout<Element>.stride
                unsafe Swift.withUnsafeBytes(of: elements) { bytes in
                    let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for i in 0..<count {
                        let elementPtr = unsafe (basePtr + i * stride)
                            .assumingMemoryBound(to: Element.self)
                        unsafe elementPtr.deinitialize(count: 1)
                    }
                }
            }
        }

        // MARK: - Small (SmallVec Pattern)

        /// An ordered set with small-buffer optimization (SmallVec pattern).
        @safe
        public struct Small<let inlineCapacity: Int>: ~Copyable {
            @inlinable
            public static var maxElementStride: Int { 64 }

            public var inlineElements: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

            public var storedCount: Int

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
                self.storedCount = 0
                self.heapStorage = nil
                self.heapHashTable = nil
            }

            deinit {
                let count = storedCount
                guard count > 0 else { return }

                if heapStorage != nil {
                    // Storage deinit handles cleanup via its count property
                    heapStorage!.count = Index_Primitives.Index<Element>.Count(UInt(count))
                } else {
                    let stride = MemoryLayout<Element>.stride
                    unsafe Swift.withUnsafeBytes(of: inlineElements) { bytes in
                        let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                        for i in 0..<count {
                            let elementPtr = unsafe (basePtr + i * stride)
                                .assumingMemoryBound(to: Element.self)
                            unsafe elementPtr.deinitialize(count: 1)
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
