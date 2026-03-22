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
import Sequence_Primitives
internal import Property_Primitives

// MARK: - Sequence.Drain.Protocol Conformance

extension Set_Primitives_Core.Set.Ordered.Fixed: Sequence.Drain.`Protocol` {
    // drain(_ body:) method already exists in Set.Ordered.Fixed.swift
}

// MARK: - Property Accessor

extension Set_Primitives_Core.Set.Ordered.Fixed {
    /// Property accessor for `.drain { }` syntax.
    ///
    /// Draining removes all elements from the set, passing each to the closure.
    /// The set survives but is empty after draining.
    ///
    /// ```swift
    /// var set = Set<Int>.Ordered.Fixed([1, 2, 3], capacity: 10)
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
