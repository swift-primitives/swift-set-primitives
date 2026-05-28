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

import Set_Primitives_Test_Support
import Testing

// The relational defaults declared on `Set.Protocol` in
// `Set_Protocol_Primitives` are exercised here against `Set.Fixture`, the
// minimal `Set.Protocol` conformer that lives in the Test Support module.
// `Set.Fixture` carries no storage discipline — it is the protocol-level
// behavioural vehicle, deliberately distinct from the storage variants in
// sibling packages.
//
// The suite anchors on a non-generic namespace because `Set.Fixture` is a
// member of the generic `Set<Element>` namespace, and the Swift Testing
// `@Suite` / `@Test` macros reject declarations in a generic context. Every
// test references the source-domain type `Set<Int>.Fixture` directly.

@Suite("Set.Protocol Relational Defaults")
struct Test {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

// MARK: - Unit

extension Test.Unit {

    // MARK: isEmpty

    @Test
    func `isEmpty is true for the empty set`() {
        let empty = Set<Int>.Fixture([])
        #expect(empty.isEmpty)
    }

    @Test
    func `isEmpty is false for a non-empty set`() {
        let set = Set<Int>.Fixture([1])
        #expect(!set.isEmpty)
    }

    // MARK: count

    @Test
    func `count reflects the number of unique elements`() {
        let set = Set<Int>.Fixture([1, 2, 3])
        #expect(set.count == 3)
    }

    @Test
    func `count drops duplicates supplied at construction`() {
        let set = Set<Int>.Fixture([1, 2, 2, 3, 3, 3])
        #expect(set.count == 3)
    }

    // MARK: isDisjoint

    @Test
    func `disjoint sets report disjoint`() {
        let a = Set<Int>.Fixture([1, 2])
        let b = Set<Int>.Fixture([3, 4])
        #expect(a.isDisjoint(with: b))
    }

    @Test
    func `overlapping sets are not disjoint`() {
        let a = Set<Int>.Fixture([1, 2, 3])
        let b = Set<Int>.Fixture([2, 4])
        #expect(!a.isDisjoint(with: b))
    }

    // MARK: isSubset

    @Test
    func `a proper subset is a subset`() {
        let small = Set<Int>.Fixture([1, 2])
        let large = Set<Int>.Fixture([1, 2, 3])
        #expect(small.isSubset(of: large))
        #expect(!large.isSubset(of: small))
    }

    // MARK: isSuperset

    @Test
    func `a proper superset is a superset`() {
        let large = Set<Int>.Fixture([1, 2, 3])
        let small = Set<Int>.Fixture([1, 2])
        #expect(large.isSuperset(of: small))
        #expect(!small.isSuperset(of: large))
    }

    // MARK: isStrictSubset

    @Test
    func `a proper subset is a strict subset`() {
        let small = Set<Int>.Fixture([1, 2])
        let large = Set<Int>.Fixture([1, 2, 3])
        #expect(small.isStrictSubset(of: large))
    }

    @Test
    func `equal sets are not strict subsets`() {
        let a = Set<Int>.Fixture([1, 2])
        let b = Set<Int>.Fixture([1, 2])
        #expect(!a.isStrictSubset(of: b))
    }

    // MARK: isStrictSuperset

    @Test
    func `a proper superset is a strict superset`() {
        let large = Set<Int>.Fixture([1, 2, 3])
        let small = Set<Int>.Fixture([1, 2])
        #expect(large.isStrictSuperset(of: small))
    }

    @Test
    func `equal sets are not strict supersets`() {
        let a = Set<Int>.Fixture([1, 2])
        let b = Set<Int>.Fixture([1, 2])
        #expect(!a.isStrictSuperset(of: b))
    }

    // MARK: isEqual

    @Test
    func `sets with the same elements are equal`() {
        let a = Set<Int>.Fixture([1, 2, 3])
        let b = Set<Int>.Fixture([3, 2, 1])
        #expect(a.isEqual(to: b))
    }

    @Test
    func `sets with different counts are not equal`() {
        let a = Set<Int>.Fixture([1, 2])
        let b = Set<Int>.Fixture([1, 2, 3])
        #expect(!a.isEqual(to: b))
    }

    @Test
    func `sets with the same count but different elements are not equal`() {
        let a = Set<Int>.Fixture([1, 2])
        let b = Set<Int>.Fixture([2, 3])
        #expect(!a.isEqual(to: b))
    }
}

// MARK: - Edge Case

extension Test.`Edge Case` {

    @Test
    func `the empty set is disjoint with every set`() {
        let empty = Set<Int>.Fixture([])
        let nonEmpty = Set<Int>.Fixture([1])
        #expect(empty.isDisjoint(with: nonEmpty))
        #expect(nonEmpty.isDisjoint(with: empty))
        #expect(empty.isDisjoint(with: empty))
    }

    @Test
    func `the empty set is a subset of every set`() {
        let empty = Set<Int>.Fixture([])
        let nonEmpty = Set<Int>.Fixture([1])
        #expect(empty.isSubset(of: nonEmpty))
        #expect(empty.isSubset(of: empty))
    }

    @Test
    func `every set is a superset of the empty set`() {
        let empty = Set<Int>.Fixture([])
        let nonEmpty = Set<Int>.Fixture([1])
        #expect(nonEmpty.isSuperset(of: empty))
        #expect(empty.isSuperset(of: empty))
    }

    @Test
    func `the empty set is a strict subset of any non-empty set`() {
        let empty = Set<Int>.Fixture([])
        let nonEmpty = Set<Int>.Fixture([1])
        #expect(empty.isStrictSubset(of: nonEmpty))
        #expect(!empty.isStrictSubset(of: empty))
    }

    @Test
    func `empty sets are equal`() {
        let a = Set<Int>.Fixture([])
        let b = Set<Int>.Fixture([])
        #expect(a.isEqual(to: b))
    }

    @Test
    func `a set equals itself`() {
        let set = Set<Int>.Fixture([1, 2, 3])
        #expect(set.isEqual(to: set))
        #expect(set.isSubset(of: set))
        #expect(set.isSuperset(of: set))
        #expect(!set.isStrictSubset(of: set))
        #expect(!set.isStrictSuperset(of: set))
    }
}

// MARK: - Integration

extension Test.Integration {

    @Test
    func `subset and superset agree across a pair`() {
        let small = Set<Int>.Fixture([1, 2])
        let large = Set<Int>.Fixture([1, 2, 3, 4])
        #expect(small.isSubset(of: large))
        #expect(large.isSuperset(of: small))
        #expect(small.isStrictSubset(of: large))
        #expect(large.isStrictSuperset(of: small))
        #expect(!small.isDisjoint(with: large))
    }

    @Test
    func `equality implies mutual subset without strictness`() {
        let a = Set<Int>.Fixture([1, 2, 3])
        let b = Set<Int>.Fixture([1, 2, 3])
        #expect(a.isEqual(to: b))
        #expect(a.isSubset(of: b))
        #expect(b.isSubset(of: a))
        #expect(!a.isStrictSubset(of: b))
        #expect(!a.isStrictSuperset(of: b))
    }

    @Test
    func `disjoint non-empty sets are neither subset nor superset`() {
        let a = Set<Int>.Fixture([1, 2])
        let b = Set<Int>.Fixture([3, 4])
        #expect(a.isDisjoint(with: b))
        #expect(!a.isSubset(of: b))
        #expect(!a.isSuperset(of: b))
        #expect(!a.isEqual(to: b))
    }
}
