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

public import Set_Primitive
public import Set_Protocol_Primitives

// MARK: - Free `@Set.Builder` DSL entry (growable conformers)
//
// The one free protocol-extension default that gives every growable
// `Set.Buildable.`Protocol`` conformer (`Set.Ordered`, `Set.Ordered.Small`) the
// `X { 1; 2; if … }` DSL — build the `[Element]` via the hoisted family
// `Set.Builder`, then finalize through the conformer's `init()` + `insert`.
//
// Non-throwing: growable inserts cannot fail (no capacity bound). Bounded
// disciplines (`Set.Ordered.Static`/`.Fixed`) genuinely CAN overflow, so they
// are NOT `Set.Buildable.`Protocol`` conformers and instead carry a one-line
// per-variant `init(@Set.Builder …)` that THROWS — the call site `try
// Set.Static { … }` makes the overflow explicit (capability model §4.2: bounded
// ≠ BuildableSet).

extension Set.Buildable.`Protocol` where Self: ~Copyable, Element: Copyable {
    /// Constructs a growable set from a `@Set.Builder` closure. Insertion order
    /// preserved; duplicates after the first occurrence collapse on insert.
    @inlinable
    public init(@Set<Element>.Builder _ content: () -> [Element]) {
        self.init()
        for element in content() { _ = self.insert(element) }
    }
}
