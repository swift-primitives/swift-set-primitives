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

import Testing
@testable import Set_Primitives

@Suite("Set<Bit>.Packed")
struct SetBitPackedTests {

    // Helper to create Bit.Index from Int
    func idx(_ n: Int) -> Bit.Index {
        Bit.Index(__unchecked: (), position: n)
    }

    // MARK: - Basic Operations

    @Test("Insert and contains")
    func insertAndContains() throws {
        var set = Set<Bit>.Packed()

        #expect(try set.insert(idx(0)) == true)
        #expect(try set.insert(idx(1)) == true)
        #expect(try set.insert(idx(63)) == true)
        #expect(try set.insert(idx(64)) == true)
        #expect(try set.insert(idx(127)) == true)

        #expect(set.contains(idx(0)))
        #expect(set.contains(idx(1)))
        #expect(set.contains(idx(63)))
        #expect(set.contains(idx(64)))
        #expect(set.contains(idx(127)))

        #expect(!set.contains(idx(2)))
        #expect(!set.contains(idx(65)))
        #expect(!set.contains(idx(1000)))
    }

    @Test("Insert returns false for existing")
    func insertReturnsFalse() throws {
        var set = Set<Bit>.Packed()

        #expect(try set.insert(idx(42)) == true)
        #expect(try set.insert(idx(42)) == false)
    }

    @Test("Remove")
    func remove() throws {
        var set = Set<Bit>.Packed()
        try set.insert(idx(10))
        try set.insert(idx(20))
        try set.insert(idx(30))

        #expect(try set.remove(idx(20)) == true)
        #expect(!set.contains(idx(20)))
        #expect(set.contains(idx(10)))
        #expect(set.contains(idx(30)))

        #expect(try set.remove(idx(20)) == false)
    }

    @Test("Negative element not contained")
    func negativeNotContained() {
        let set = Set<Bit>.Packed()
        #expect(!set.contains(idx(-1)))
        #expect(!set.contains(idx(-100)))
    }

    // MARK: - Word Boundaries

    @Test("Word boundary: 63 and 64")
    func wordBoundary63And64() throws {
        var set = Set<Bit>.Packed()
        try set.insert(idx(63))
        try set.insert(idx(64))

        #expect(set.contains(idx(63)))
        #expect(set.contains(idx(64)))
        #expect(!set.contains(idx(62)))
        #expect(!set.contains(idx(65)))
    }

    @Test("Word boundary: 127 and 128")
    func wordBoundary127And128() throws {
        var set = Set<Bit>.Packed()
        try set.insert(idx(127))
        try set.insert(idx(128))

        #expect(set.contains(idx(127)))
        #expect(set.contains(idx(128)))
        #expect(!set.contains(idx(126)))
        #expect(!set.contains(idx(129)))
    }

    @Test("Large elements")
    func largeElements() throws {
        var set = Set<Bit>.Packed()
        try set.insert(idx(1000))
        try set.insert(idx(10000))
        try set.insert(idx(100000))

        #expect(set.contains(idx(1000)))
        #expect(set.contains(idx(10000)))
        #expect(set.contains(idx(100000)))
        #expect(set.count == 3)
    }

    // MARK: - Properties

    @Test("Count")
    func count() throws {
        var set = Set<Bit>.Packed()
        #expect(set.isEmpty)

        try set.insert(idx(0))
        #expect(set.count == 1)

        try set.insert(idx(64))
        #expect(set.count == 2)

        try set.insert(idx(128))
        #expect(set.count == 3)

        try set.remove(idx(64))
        #expect(set.count == 2)
    }

    @Test("isEmpty")
    func isEmpty() throws {
        var set = Set<Bit>.Packed()
        #expect(set.isEmpty)

        try set.insert(idx(42))
        #expect(!set.isEmpty)

        try set.remove(idx(42))
        #expect(set.isEmpty)
    }

    @Test("Min and max")
    func minAndMax() throws {
        var set = Set<Bit>.Packed()
        #expect(set.min == nil)
        #expect(set.max == nil)

        try set.insert(idx(50))
        #expect(set.min == idx(50))
        #expect(set.max == idx(50))

        try set.insert(idx(10))
        try set.insert(idx(90))
        #expect(set.min == idx(10))
        #expect(set.max == idx(90))

        try set.insert(idx(0))
        try set.insert(idx(200))
        #expect(set.min == idx(0))
        #expect(set.max == idx(200))
    }

    @Test("Clear")
    func clear() throws {
        var set = Set<Bit>.Packed()
        try set.insert(idx(1))
        try set.insert(idx(2))
        try set.insert(idx(3))

        set.clear()
        #expect(set.isEmpty)
    }

    // MARK: - Initialization

    @Test("Init from sequence")
    func initFromSequence() {
        let set = Set<Bit>.Packed([idx(1), idx(2), idx(3), idx(64), idx(65), idx(66)])

        #expect(set.count == 6)
        #expect(set.contains(idx(1)))
        #expect(set.contains(idx(2)))
        #expect(set.contains(idx(3)))
        #expect(set.contains(idx(64)))
        #expect(set.contains(idx(65)))
        #expect(set.contains(idx(66)))
    }

    @Test("Init with duplicates")
    func initWithDuplicates() {
        let set = Set<Bit>.Packed([idx(1), idx(2), idx(1), idx(3), idx(2), idx(1)])
        #expect(set.count == 3)
    }

    // MARK: - Iteration

    @Test("Iteration order")
    func iterationOrder() throws {
        var set = Set<Bit>.Packed()
        try set.insert(idx(100))
        try set.insert(idx(10))
        try set.insert(idx(50))
        try set.insert(idx(1))

        let elements = Swift.Array(set)
        #expect(elements == [idx(1), idx(10), idx(50), idx(100)])
    }

    @Test("Iteration across word boundaries")
    func iterationAcrossWordBoundaries() throws {
        var set = Set<Bit>.Packed()
        try set.insert(idx(0))
        try set.insert(idx(63))
        try set.insert(idx(64))
        try set.insert(idx(127))
        try set.insert(idx(128))

        let elements = Swift.Array(set)
        #expect(elements == [idx(0), idx(63), idx(64), idx(127), idx(128)])
    }

    // MARK: - Set Algebra

    @Test("Union")
    func union() {
        let a = Set<Bit>.Packed([idx(1), idx(2), idx(3)])
        let b = Set<Bit>.Packed([idx(3), idx(4), idx(5)])

        let result = a.union(b)

        #expect(result.count == 5)
        for i in 1...5 {
            #expect(result.contains(idx(i)))
        }
    }

    @Test("Intersection")
    func intersection() {
        let a = Set<Bit>.Packed([idx(1), idx(2), idx(3), idx(4)])
        let b = Set<Bit>.Packed([idx(3), idx(4), idx(5), idx(6)])

        let result = a.intersection(b)

        #expect(result.count == 2)
        #expect(result.contains(idx(3)))
        #expect(result.contains(idx(4)))
        #expect(!result.contains(idx(1)))
        #expect(!result.contains(idx(5)))
    }

    @Test("Subtracting")
    func subtracting() {
        let a = Set<Bit>.Packed([idx(1), idx(2), idx(3), idx(4), idx(5)])
        let b = Set<Bit>.Packed([idx(2), idx(4)])

        let result = a.subtracting(b)

        #expect(result.count == 3)
        #expect(result.contains(idx(1)))
        #expect(result.contains(idx(3)))
        #expect(result.contains(idx(5)))
        #expect(!result.contains(idx(2)))
        #expect(!result.contains(idx(4)))
    }

    @Test("Symmetric difference")
    func symmetricDifference() {
        let a = Set<Bit>.Packed([idx(1), idx(2), idx(3)])
        let b = Set<Bit>.Packed([idx(2), idx(3), idx(4)])

        let result = a.symmetricDifference(b)

        #expect(result.count == 2)
        #expect(result.contains(idx(1)))
        #expect(result.contains(idx(4)))
        #expect(!result.contains(idx(2)))
        #expect(!result.contains(idx(3)))
    }

    @Test("Union across word boundaries")
    func unionAcrossWordBoundaries() {
        let a = Set<Bit>.Packed([idx(0), idx(63)])
        let b = Set<Bit>.Packed([idx(64), idx(127)])

        let result = a.union(b)

        #expect(result.count == 4)
        #expect(result.contains(idx(0)))
        #expect(result.contains(idx(63)))
        #expect(result.contains(idx(64)))
        #expect(result.contains(idx(127)))
    }

    // MARK: - Predicates

    @Test("isSubset")
    func isSubset() {
        let small = Set<Bit>.Packed([idx(1), idx(2), idx(3)])
        let large = Set<Bit>.Packed([idx(1), idx(2), idx(3), idx(4), idx(5)])
        let disjoint = Set<Bit>.Packed([idx(10), idx(11), idx(12)])

        #expect(small.isSubset(of: large))
        #expect(!large.isSubset(of: small))
        #expect(!small.isSubset(of: disjoint))
        #expect(small.isSubset(of: small))  // Every set is subset of itself
    }

    @Test("isSuperset")
    func isSuperset() {
        let small = Set<Bit>.Packed([idx(1), idx(2), idx(3)])
        let large = Set<Bit>.Packed([idx(1), idx(2), idx(3), idx(4), idx(5)])

        #expect(large.isSuperset(of: small))
        #expect(!small.isSuperset(of: large))
        #expect(small.isSuperset(of: small))  // Every set is superset of itself
    }

    @Test("isDisjoint")
    func isDisjoint() {
        let a = Set<Bit>.Packed([idx(1), idx(2), idx(3)])
        let b = Set<Bit>.Packed([idx(4), idx(5), idx(6)])
        let c = Set<Bit>.Packed([idx(3), idx(4), idx(5)])

        #expect(a.isDisjoint(with: b))
        #expect(!a.isDisjoint(with: c))
    }

    // MARK: - Equality

    @Test("Equality")
    func equality() {
        let a = Set<Bit>.Packed([idx(1), idx(2), idx(3)])
        let b = Set<Bit>.Packed([idx(1), idx(2), idx(3)])
        let c = Set<Bit>.Packed([idx(1), idx(2), idx(4)])

        #expect(a == b)
        #expect(a != c)
    }

    @Test("Empty sets equal")
    func emptySetsEqual() {
        let a = Set<Bit>.Packed()
        let b = Set<Bit>.Packed()
        #expect(a == b)
    }

    // MARK: - Description

    @Test("Description")
    func description() {
        let set = Set<Bit>.Packed([idx(1), idx(2), idx(3)])
        let desc = set.description
        #expect(desc.contains("Set<Bit>.Packed"))
        #expect(desc.contains("1"))
        #expect(desc.contains("2"))
        #expect(desc.contains("3"))
    }
}
