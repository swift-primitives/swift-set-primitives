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
import Set_Primitives_Test_Support

@Suite("Set<Bit>.Packed")
struct SetBitPackedTests {

    // MARK: - Basic Operations

    @Test
    func `Insert and contains`() throws {
        var set = Set<Bit>.Packed()

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

    @Test
    func `Insert returns false for existing`() throws {
        var set = Set<Bit>.Packed()

        #expect(try set.insert(42) == true)
        #expect(try set.insert(42) == false)
    }

    @Test
    func `Remove`() throws {
        var set = Set<Bit>.Packed()
        try set.insert(10)
        try set.insert(20)
        try set.insert(30)

        #expect(try set.remove(20) == true)
        #expect(!set.contains(20))
        #expect(set.contains(10))
        #expect(set.contains(30))

        #expect(try set.remove(20) == false)
    }

    @Test
    func `Negative element not contained`() {
        let set = Set<Bit>.Packed()
        // Negative indices are invalid - they would throw on construction
        // Testing that the set doesn't crash on boundary checks
        #expect(set.isEmpty)
    }

    // MARK: - Word Boundaries

    @Test
    func `Word boundary: 63 and 64`() throws {
        var set = Set<Bit>.Packed()
        try set.insert(63)
        try set.insert(64)

        #expect(set.contains(63))
        #expect(set.contains(64))
        #expect(!set.contains(62))
        #expect(!set.contains(65))
    }

    @Test
    func `Word boundary: 127 and 128`() throws {
        var set = Set<Bit>.Packed()
        try set.insert(127)
        try set.insert(128)

        #expect(set.contains(127))
        #expect(set.contains(128))
        #expect(!set.contains(126))
        #expect(!set.contains(129))
    }

    @Test
    func `Large elements`() throws {
        var set = Set<Bit>.Packed()
        try set.insert(1000)
        try set.insert(10000)
        try set.insert(100000)

        #expect(set.contains(1000))
        #expect(set.contains(10000))
        #expect(set.contains(100000))
        #expect(set.count == 3)
    }

    // MARK: - Properties

    @Test
    func `Count`() throws {
        var set = Set<Bit>.Packed()
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

    @Test
    func `isEmpty`() throws {
        var set = Set<Bit>.Packed()
        #expect(set.isEmpty)

        try set.insert(42)
        #expect(!set.isEmpty)

        try set.remove(42)
        #expect(set.isEmpty)
    }

    @Test
    func `Min and max`() throws {
        var set = Set<Bit>.Packed()
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

    @Test
    func `Clear`() throws {
        var set = Set<Bit>.Packed()
        try set.insert(1)
        try set.insert(2)
        try set.insert(3)

        set.clear()
        #expect(set.isEmpty)
    }

    // MARK: - Initialization

    @Test
    func `Init from sequence`() {
        let indices: [Bit.Index] = [1, 2, 3, 64, 65, 66]
        let set = Set<Bit>.Packed(indices)

        #expect(set.count == 6)
        #expect(set.contains(1))
        #expect(set.contains(2))
        #expect(set.contains(3))
        #expect(set.contains(64))
        #expect(set.contains(65))
        #expect(set.contains(66))
    }

    @Test
    func `Init with duplicates`() {
        let indices: [Bit.Index] = [1, 2, 1, 3, 2, 1]
        let set = Set<Bit>.Packed(indices)
        #expect(set.count == 3)
    }

    // MARK: - Iteration

    @Test
    func `Iteration order`() throws {
        var set = Set<Bit>.Packed()
        try set.insert(100)
        try set.insert(10)
        try set.insert(50)
        try set.insert(1)

        let elements = Swift.Array(set)
        let expected: [Bit.Index] = [1, 10, 50, 100]
        #expect(elements == expected)
    }

    @Test
    func `Iteration across word boundaries`() throws {
        var set = Set<Bit>.Packed()
        try set.insert(0)
        try set.insert(63)
        try set.insert(64)
        try set.insert(127)
        try set.insert(128)

        let elements = Swift.Array(set)
        let expected: [Bit.Index] = [0, 63, 64, 127, 128]
        #expect(elements == expected)
    }

    // MARK: - Set Algebra

    @Test
    func `Union`() {
        let a = Set<Bit>.Packed([1, 2, 3])
        let b = Set<Bit>.Packed([3, 4, 5])

        let result = a.algebra.union(b)

        #expect(result.count == 5)
        #expect(result.contains(1))
        #expect(result.contains(2))
        #expect(result.contains(3))
        #expect(result.contains(4))
        #expect(result.contains(5))
    }

    @Test
    func `Intersection`() {
        let a = Set<Bit>.Packed([1, 2, 3, 4])
        let b = Set<Bit>.Packed([3, 4, 5, 6])

        let result = a.algebra.intersection(b)

        #expect(result.count == 2)
        #expect(result.contains(3))
        #expect(result.contains(4))
        #expect(!result.contains(1))
        #expect(!result.contains(5))
    }

    @Test
    func `Subtracting`() {
        let a = Set<Bit>.Packed([1, 2, 3, 4, 5])
        let b = Set<Bit>.Packed([2, 4])

        let result = a.algebra.subtract(b)

        #expect(result.count == 3)
        #expect(result.contains(1))
        #expect(result.contains(3))
        #expect(result.contains(5))
        #expect(!result.contains(2))
        #expect(!result.contains(4))
    }

    @Test
    func `Symmetric difference`() {
        let a = Set<Bit>.Packed([1, 2, 3])
        let b = Set<Bit>.Packed([2, 3, 4])

        let result = a.algebra.symmetric.difference(b)

        #expect(result.count == 2)
        #expect(result.contains(1))
        #expect(result.contains(4))
        #expect(!result.contains(2))
        #expect(!result.contains(3))
    }

    @Test
    func `Union across word boundaries`() {
        let a = Set<Bit>.Packed([0, 63])
        let b = Set<Bit>.Packed([64, 127])

        let result = a.algebra.union(b)

        #expect(result.count == 4)
        #expect(result.contains(0))
        #expect(result.contains(63))
        #expect(result.contains(64))
        #expect(result.contains(127))
    }

    // MARK: - Predicates

    @Test
    func `isSubset`() {
        let small = Set<Bit>.Packed([1, 2, 3])
        let large = Set<Bit>.Packed([1, 2, 3, 4, 5])
        let disjoint = Set<Bit>.Packed([10, 11, 12])

        #expect(small.relation.isSubset(of: large))
        #expect(!large.relation.isSubset(of: small))
        #expect(!small.relation.isSubset(of: disjoint))
        #expect(small.relation.isSubset(of: small))  // Every set is subset of itself
    }

    @Test
    func `isSuperset`() {
        let small = Set<Bit>.Packed([1, 2, 3])
        let large = Set<Bit>.Packed([1, 2, 3, 4, 5])

        #expect(large.relation.isSuperset(of: small))
        #expect(!small.relation.isSuperset(of: large))
        #expect(small.relation.isSuperset(of: small))  // Every set is superset of itself
    }

    @Test
    func `isDisjoint`() {
        let a = Set<Bit>.Packed([1, 2, 3])
        let b = Set<Bit>.Packed([4, 5, 6])
        let c = Set<Bit>.Packed([3, 4, 5])

        #expect(a.relation.isDisjoint(with: b))
        #expect(!a.relation.isDisjoint(with: c))
    }

    // MARK: - Equality

    @Test
    func `Equality`() {
        let a = Set<Bit>.Packed([1, 2, 3])
        let b = Set<Bit>.Packed([1, 2, 3])
        let c = Set<Bit>.Packed([1, 2, 4])

        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func `Empty sets equal`() {
        let a = Set<Bit>.Packed()
        let b = Set<Bit>.Packed()
        #expect(a == b)
    }

    // MARK: - Description

    @Test
    func `Description`() {
        let set = Set<Bit>.Packed([1, 2, 3])
        let desc = set.description
        #expect(desc.contains("Set<Bit>.Packed"))
        #expect(desc.contains("1"))
        #expect(desc.contains("2"))
        #expect(desc.contains("3"))
    }
}
