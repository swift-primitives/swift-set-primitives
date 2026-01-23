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

public import Bit_Primitives

extension Set<Bit>.Packed.Inline.Algebra {
    /// Namespace for symmetric set operations.
    public struct Symmetric: Sendable {
        @usableFromInline
        let storage: InlineArray<wordCount, UInt>

        @usableFromInline
        init(storage: InlineArray<wordCount, UInt>) {
            self.storage = storage
        }
    }
}

// MARK: - Symmetric Operations

extension Set<Bit>.Packed.Inline.Algebra.Symmetric {
    /// Returns a new set with elements in either set, but not both.
    ///
    /// - Parameter other: The other set.
    /// - Returns: A new set with elements in exactly one of the sets.
    @inlinable
    public func difference(_ other: Set<Bit>.Packed.Inline<wordCount>) -> Set<Bit>.Packed.Inline<wordCount> {
        var resultStorage = storage
        for i in 0..<wordCount {
            resultStorage[i] ^= other.storage[i]
        }
        return Set<Bit>.Packed.Inline<wordCount>(__storage: resultStorage)
    }
}
