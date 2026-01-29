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
public import Bit_Primitives

// MARK: - Error Typealiases for Variant Types

extension Set<Bit>.Packed.Bounded {
    /// Errors that can occur during bounded packed bit set operations.
    public typealias Error = __SetBitPackedBoundedError
}

extension Set<Bit>.Packed.Inline {
    /// Errors that can occur during inline packed bit set operations.
    public typealias Error = __SetBitPackedInlineError
}

extension Set<Bit>.Packed.Small {
    /// Errors that can occur during small packed bit set operations.
    public typealias Error = __SetBitPackedSmallError
}
