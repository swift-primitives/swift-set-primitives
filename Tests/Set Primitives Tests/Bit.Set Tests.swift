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

@Suite("Bit.Set")
struct BitSetTests {

    // MARK: - Basic Operations

    @Test("Insert and contains")
    func insertAndContains() throws {
        var set = Bit.Set()

        #expect(try set.insert(0) == true)
        #expect(try set.insert(1) == true)
        #expect(try set.insert(63) == true)
        #expect(try set.insert(64) == true)
        #expect(try set.insert(127) == true)

        #expect(set.contains(0))
        #expect(set.contains(1))
        #expect(set.contains(63))
        #expect(set.contains(64))
        #expect(set.contains(127))

        #expect(!set.contains(2))
        #expect(!set.contains(65))
        #expect(!set.contains(1000))
    }

    @Test("Insert returns false for existing")
    func insertReturnsFalse() throws {
        var set = Bit.Set()

        #expect(try set.insert(42) == true)
        #expect(try set.insert(42) == false)
    }

    @Test("Remove")
    func remove() throws {
        var set = Bit.Set()
        try set.insert(10)
        try set.insert(20)
        try set.insert(30)

        #expect(try set.remove(20) == true)
        #expect(!set.contains(20))
        #expect(set.contains(10))
        #expect(set.contains(30))

        #expect(try set.remove(20) == false)
    }

    @Test("Negative element not contained")
    func negativeNotContained() {
        let set = Bit.Set()
        #expect(!set.contains(-1))
        #expect(!set.contains(-100))
    }

    // MARK: - Word Boundaries

    @Test("Word boundary: 63 and 64")
    func wordBoundary63And64() throws {
        var set = Bit.Set()
        try set.insert(63)
        try set.insert(64)

        #expect(set.contains(63))
        #expect(set.contains(64))
        #expect(!set.contains(62))
        #expect(!set.contains(65))
    }

    @Test("Word boundary: 127 and 128")
    func wordBoundary127And128() throws {
        var set = Bit.Set()
        try set.insert(127)
        try set.insert(128)

        #expect(set.contains(127))
        #expect(set.contains(128))
        #expect(!set.contains(126))
        #expect(!set.contains(129))
    }

    @Test("Large elements")
    func largeElements() throws {
        var set = Bit.Set()
        try set.insert(1000)
        try set.insert(10000)
        try set.insert(100000)

        #expect(set.contains(1000))
        #expect(set.contains(10000))
        #expect(set.contains(100000))
        #expect(set.count == 3)
    }

    // MARK: - Properties

    @Test("Count")
    func count() throws {
        var set = Bit.Set()
        #expect(set.isEmpty)

        try set.insert(0)
        #expect(set.count == 1)

        try set.insert(64)
        #expect(set.count == 2)

        try set.insert(128)
        #expect(set.count == 3)

        try set.remove(64)
        #expect(set.count == 2)
    }

    @Test("isEmpty")
    func isEmpty() throws {
        var set = Bit.Set()
        #expect(set.isEmpty)

        try set.insert(42)
        #expect(!set.isEmpty)

        try set.remove(42)
        #expect(set.isEmpty)
    }

    @Test("Min and max")
    func minAndMax() throws {
        var set = Bit.Set()
        #expect(set.min == nil)
        #expect(set.max == nil)

        try set.insert(50)
        #expect(set.min == 50)
        #expect(set.max == 50)

        try set.insert(10)
        try set.insert(90)
        #expect(set.min == 10)
        #expect(set.max == 90)

        try set.insert(0)
        try set.insert(200)
        #expect(set.min == 0)
        #expect(set.max == 200)
    }

    @Test("Clear")
    func clear() throws {
        var set = Bit.Set()
        try set.insert(1)
        try set.insert(2)
        try set.insert(3)

        set.clear()
        #expect(set.isEmpty)
    }

    // MARK: - Initialization

    @Test("Init from sequence")
    func initFromSequence() {
        let set = Bit.Set([1, 2, 3, 64, 65, 66])

        #expect(set.count == 6)
        #expect(set.contains(1))
        #expect(set.contains(2))
        #expect(set.contains(3))
        #expect(set.contains(64))
        #expect(set.contains(65))
        #expect(set.contains(66))
    }

    @Test("Init with duplicates")
    func initWithDuplicates() {
        let set = Bit.Set([1, 2, 1, 3, 2, 1])
        #expect(set.count == 3)
    }

    // MARK: - Iteration

    @Test("Iteration order")
    func iterationOrder() throws {
        var set = Bit.Set()
        try set.insert(100)
        try set.insert(10)
        try set.insert(50)
        try set.insert(1)

        let elements = Swift.Array(set)
        #expect(elements == [1, 10, 50, 100])
    }

    @Test("Iteration across word boundaries")
    func iterationAcrossWordBoundaries() throws {
        var set = Bit.Set()
        try set.insert(0)
        try set.insert(63)
        try set.insert(64)
        try set.insert(127)
        try set.insert(128)

        let elements = Swift.Array(set)
        #expect(elements == [0, 63, 64, 127, 128])
    }

    // MARK: - Set Algebra

    @Test("Union")
    func union() {
        let a = Bit.Set([1, 2, 3])
        let b = Bit.Set([3, 4, 5])

        let result = a.union(b)

        #expect(result.count == 5)
        for i in 1...5 {
            #expect(result.contains(i))
        }
    }

    @Test("Intersection")
    func intersection() {
        let a = Bit.Set([1, 2, 3, 4])
        let b = Bit.Set([3, 4, 5, 6])

        let result = a.intersection(b)

        #expect(result.count == 2)
        #expect(result.contains(3))
        #expect(result.contains(4))
        #expect(!result.contains(1))
        #expect(!result.contains(5))
    }

    @Test("Subtracting")
    func subtracting() {
        let a = Bit.Set([1, 2, 3, 4, 5])
        let b = Bit.Set([2, 4])

        let result = a.subtracting(b)

        #expect(result.count == 3)
        #expect(result.contains(1))
        #expect(result.contains(3))
        #expect(result.contains(5))
        #expect(!result.contains(2))
        #expect(!result.contains(4))
    }

    @Test("Symmetric difference")
    func symmetricDifference() {
        let a = Bit.Set([1, 2, 3])
        let b = Bit.Set([2, 3, 4])

        let result = a.symmetricDifference(b)

        #expect(result.count == 2)
        #expect(result.contains(1))
        #expect(result.contains(4))
        #expect(!result.contains(2))
        #expect(!result.contains(3))
    }

    @Test("Union across word boundaries")
    func unionAcrossWordBoundaries() {
        let a = Bit.Set([0, 63])
        let b = Bit.Set([64, 127])

        let result = a.union(b)

        #expect(result.count == 4)
        #expect(result.contains(0))
        #expect(result.contains(63))
        #expect(result.contains(64))
        #expect(result.contains(127))
    }

    // MARK: - Predicates

    @Test("isSubset")
    func isSubset() {
        let small = Bit.Set([1, 2, 3])
        let large = Bit.Set([1, 2, 3, 4, 5])
        let disjoint = Bit.Set([10, 11, 12])

        #expect(small.isSubset(of: large))
        #expect(!large.isSubset(of: small))
        #expect(!small.isSubset(of: disjoint))
        #expect(small.isSubset(of: small))  // Every set is subset of itself
    }

    @Test("isSuperset")
    func isSuperset() {
        let small = Bit.Set([1, 2, 3])
        let large = Bit.Set([1, 2, 3, 4, 5])

        #expect(large.isSuperset(of: small))
        #expect(!small.isSuperset(of: large))
        #expect(small.isSuperset(of: small))  // Every set is superset of itself
    }

    @Test("isDisjoint")
    func isDisjoint() {
        let a = Bit.Set([1, 2, 3])
        let b = Bit.Set([4, 5, 6])
        let c = Bit.Set([3, 4, 5])

        #expect(a.isDisjoint(with: b))
        #expect(!a.isDisjoint(with: c))
    }

    // MARK: - Equality

    @Test("Equality")
    func equality() {
        let a = Bit.Set([1, 2, 3])
        let b = Bit.Set([1, 2, 3])
        let c = Bit.Set([1, 2, 4])

        #expect(a == b)
        #expect(a != c)
    }

    @Test("Empty sets equal")
    func emptySetsEqual() {
        let a = Bit.Set()
        let b = Bit.Set()
        #expect(a == b)
    }

    // MARK: - Description

    @Test("Description")
    func description() {
        let set = Bit.Set([1, 2, 3])
        let desc = set.description
        #expect(desc.contains("Bit.Set"))
        #expect(desc.contains("1"))
        #expect(desc.contains("2"))
        #expect(desc.contains("3"))
    }
}
