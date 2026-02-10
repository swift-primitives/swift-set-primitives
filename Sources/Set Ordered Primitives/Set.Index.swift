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

import Set_Primitives_Core
import Index_Primitives

// Note: Set.Ordered now uses Index<Element> natively throughout its API.
// Set<Element>.Index is a typealias for Index_Primitives.Index<Element>.
// The subscript and element(at:) methods are defined in Set.Ordered Copyable.swift.
