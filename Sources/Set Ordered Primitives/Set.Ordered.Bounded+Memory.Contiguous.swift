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

// Note: Memory.Contiguous.Protocol conformance removed.
//
// Set.Ordered.Bounded uses closure-based span access (withSpan, withMutableSpan) rather than
// direct span properties due to Span's ~Escapable lifetime requirements. The compiler
// cannot safely verify that a Span returned from a property doesn't escape its scope.
//
// The closure-based API is principally correct for ~Escapable types.
