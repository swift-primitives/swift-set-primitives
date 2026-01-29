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
public import Sequence_Primitives
public import Property_Primitives

// MARK: - Sequence.Drain.Protocol Conformance

extension Set_Primitives_Core.Set.Ordered.Small: Sequence.Drain.`Protocol` {
    // drain(_ body:) method already exists in Set.Ordered.Small.swift
}

// MARK: - Property Accessor

extension Set_Primitives_Core.Set.Ordered.Small {
    /// Property accessor for `.drain { }` syntax.
    ///
    /// Draining removes all elements from the set, passing each to the closure.
    /// The set survives but is empty after draining.
    ///
    /// ```swift
    /// var set = Set<Int>.Ordered.Small<4>([1, 2, 3])
    /// set.drain { print($0) }  // prints 1, 2, 3
    /// // set is now empty but still usable
    /// ```
    public var drain: Property<Sequence.Drain, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View(&self)
            yield &view
        }
    }
}
