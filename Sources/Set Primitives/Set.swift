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

public import Standard_Library_Extensions

/// Namespace for ordered set types.
///
/// This shadows `Swift.Set`. Use `Swift.Set` or module-qualified
/// `Set_Primitives.Set` to disambiguate when both are in scope.
///
/// ## Key Constraint
///
/// Unlike `Dictionary` where values can be `~Copyable`, set elements must always
/// be `Hashable` (which implies `Copyable`). The `~Copyable` support here enables
/// the set **container itself** to be stored in move-only contexts.
public enum Set<Element: Hashable>: ~Copyable {}
