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

extension Set<Bit>.Vector.Fixed {
    /// Errors that can occur during Fixed packed bit set operations.
    public typealias Error = __SetBitVectorFixedError
}

extension Set<Bit>.Vector.Static {
    /// Errors that can occur during inline packed bit set operations.
    public typealias Error = __SetBitVectorInlineError
}

extension Set<Bit>.Vector.Small {
    /// Errors that can occur during small packed bit set operations.
    public typealias Error = __SetBitVectorSmallError
}
