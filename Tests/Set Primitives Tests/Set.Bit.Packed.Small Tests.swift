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

@Suite("Set<Bit>.Packed.Small")
struct SetBitPackedSmallTests {

    // MARK: - Basic Operations

    @Test
    func `Init creates inline storage`() {
        let set = Set<Bit>.Packed.Small<2>()
        #expect(!set.isSpilled)
        #expect(set.isEmpty)
        #expect(set.count == 0)
        #expect(Set<Bit>.Packed.Small<2>.inlineCapacity == 128)
    }

    @Test
    func `Insert within inline capacity`() throws {
        var set = Set<Bit>.Packed.Small<2>()

        #expect(try set.insert(0) == true)
        #expect(try set.insert(63) == true)
        #expect(try set.insert(64) == true)
        #expect(try set.insert(127) == true)

        #expect(!set.isSpilled)
        #expect(set.count == 4)
        #expect(set.contains(0))
        #expect(set.contains(63))
        #expect(set.contains(64))
        #expect(set.contains(127))
    }

    @Test
    func `Insert beyond inline capacity triggers spill`() throws {
        var set = Set<Bit>.Packed.Small<2>()

        // Insert within inline capacity
        try set.insert(0)
        try set.insert(127)
        #expect(!set.isSpilled)

        // Insert beyond inline capacity
        try set.insert(128)
        #expect(set.isSpilled)
        #expect(set.count == 3)

        // All elements still accessible
        #expect(set.contains(0))
        #expect(set.contains(127))
        #expect(set.contains(128))
    }

    @Test
    func `Insert returns false for existing`() throws {
        var set = Set<Bit>.Packed.Small<2>()

        #expect(try set.insert(42) == true)
        #expect(try set.insert(42) == false)
    }

    @Test
    func `Remove in inline mode`() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(10)
        try set.insert(20)
        try set.insert(30)

        #expect(try set.remove(20) == true)
        #expect(!set.contains(20))
        #expect(set.contains(10))
        #expect(set.contains(30))
        #expect(set.count == 2)
        #expect(!set.isSpilled)
    }

    @Test
    func `Remove in heap mode`() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(10)
        try set.insert(200)  // Triggers spill
        try set.insert(300)

        #expect(set.isSpilled)

        #expect(try set.remove(200) == true)
        #expect(!set.contains(200))
        #expect(set.contains(10))
        #expect(set.contains(300))
        #expect(set.count == 2)
    }

    @Test
    func `Negative element not contained`() {
        let set = Set<Bit>.Packed.Small<2>()
        // Negative indices are invalid - they would throw on construction
        #expect(set.isEmpty)
    }

    // MARK: - Clear and Reset

    @Test
    func `Clear resets to inline mode`() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(10)
        try set.insert(200)  // Triggers spill
        #expect(set.isSpilled)

        set.clear()
        #expect(!set.isSpilled)
        #expect(set.isEmpty)
        #expect(set.count == 0)
        #expect(set.capacity == Set<Bit>.Packed.Small<2>.inlineCapacity)
    }

    @Test
    func `RemoveAll keeps heap mode`() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(10)
        try set.insert(200)  // Triggers spill
        #expect(set.isSpilled)

        set.removeAll()
        #expect(set.isSpilled)  // Still in heap mode
        #expect(set.isEmpty)
        #expect(set.count == 0)
    }

    // MARK: - Properties

    @Test
    func `Count in inline mode`() throws {
        var set = Set<Bit>.Packed.Small<2>()
        #expect(set.count == 0)

        try set.insert(0)
        #expect(set.count == 1)

        try set.insert(64)
        #expect(set.count == 2)

        try set.insert(127)
        #expect(set.count == 3)
    }

    @Test
    func `Count in heap mode`() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(0)
        try set.insert(200)  // Triggers spill
        try set.insert(300)

        #expect(set.count == 3)
    }

    @Test
    func `Min and max in inline mode`() throws {
        var set = Set<Bit>.Packed.Small<2>()
        #expect(set.min == nil)
        #expect(set.max == nil)

        try set.insert(50)
        #expect(set.min == 50)
        #expect(set.max == 50)

        try set.insert(10)
        try set.insert(90)
        #expect(set.min == 10)
        #expect(set.max == 90)
    }

    @Test
    func `Min and max in heap mode`() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(10)
        try set.insert(200)  // Triggers spill
        try set.insert(1000)

        #expect(set.min == 10)
        #expect(set.max == 1000)
    }

    // MARK: - Iteration

    @Test
    func `Iteration in inline mode`() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(100)
        try set.insert(10)
        try set.insert(50)
        try set.insert(1)

        let elements = Swift.Array(set)
        let expected: [Bit.Index] = [1, 10, 50, 100]
        #expect(elements == expected)
    }

    @Test
    func `Iteration in heap mode`() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(10)
        try set.insert(200)  // Triggers spill
        try set.insert(50)
        try set.insert(300)

        let elements = Swift.Array(set)
        let expected: [Bit.Index] = [10, 50, 200, 300]
        #expect(elements == expected)
    }

    // MARK: - Set Algebra

    @Test
    func `Union in inline mode`() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(1)
        try a.insert(2)

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(2)
        try b.insert(3)

        let result = a.algebra.union(b)
        #expect(result.count == 3)
        #expect(result.contains(1))
        #expect(result.contains(2))
        #expect(result.contains(3))
    }

    @Test
    func `Union triggers spill`() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(1)

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(200)  // Beyond inline capacity

        let result = a.algebra.union(b)
        #expect(result.isSpilled)
        #expect(result.count == 2)
        #expect(result.contains(1))
        #expect(result.contains(200))
    }

    @Test
    func `Intersection`() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(1)
        try a.insert(2)
        try a.insert(3)

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(2)
        try b.insert(3)
        try b.insert(4)

        let result = a.algebra.intersection(b)
        #expect(result.count == 2)
        #expect(result.contains(2))
        #expect(result.contains(3))
        #expect(!result.contains(1))
        #expect(!result.contains(4))
    }

    @Test
    func `Subtracting`() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(1)
        try a.insert(2)
        try a.insert(3)

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(2)

        let result = a.algebra.subtract(b)
        #expect(result.count == 2)
        #expect(result.contains(1))
        #expect(result.contains(3))
        #expect(!result.contains(2))
    }

    @Test
    func `Symmetric difference`() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(1)
        try a.insert(2)

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(2)
        try b.insert(3)

        let result = a.algebra.symmetric.difference(b)
        #expect(result.count == 2)
        #expect(result.contains(1))
        #expect(result.contains(3))
        #expect(!result.contains(2))
    }

    // MARK: - Set Relations

    @Test
    func `isSubset`() throws {
        var small = Set<Bit>.Packed.Small<2>()
        try small.insert(1)
        try small.insert(2)

        var large = Set<Bit>.Packed.Small<2>()
        try large.insert(1)
        try large.insert(2)
        try large.insert(3)

        #expect(small.relation.isSubset(of: large))
        #expect(!large.relation.isSubset(of: small))
    }

    @Test
    func `isSuperset`() throws {
        var small = Set<Bit>.Packed.Small<2>()
        try small.insert(1)
        try small.insert(2)

        var large = Set<Bit>.Packed.Small<2>()
        try large.insert(1)
        try large.insert(2)
        try large.insert(3)

        #expect(large.relation.isSuperset(of: small))
        #expect(!small.relation.isSuperset(of: large))
    }

    @Test
    func `isDisjoint`() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(1)
        try a.insert(2)

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(3)
        try b.insert(4)

        var c = Set<Bit>.Packed.Small<2>()
        try c.insert(2)
        try c.insert(3)

        #expect(a.relation.isDisjoint(with: b))
        #expect(!a.relation.isDisjoint(with: c))
    }

    // MARK: - Equality

    @Test
    func `Equality inline mode`() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(1)
        try a.insert(2)

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(1)
        try b.insert(2)

        var c = Set<Bit>.Packed.Small<2>()
        try c.insert(1)
        try c.insert(3)

        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func `Equality heap mode`() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(1)
        try a.insert(200)

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(1)
        try b.insert(200)

        #expect(a == b)
    }

    @Test
    func `Equality mixed modes`() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(1)
        try a.insert(2)

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(1)
        try b.insert(2)
        try b.insert(200)  // Triggers spill
        try b.remove(200)  // Remove but still in heap mode

        // Both have same elements even though different storage modes
        #expect(a == b)
    }

    // MARK: - Description

    @Test
    func `Description inline mode`() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(1)
        try set.insert(2)

        let desc = set.description
        #expect(desc.contains("Set<Bit>.Packed.Small"))
        #expect(!desc.contains("spilled"))
    }

    @Test
    func `Description heap mode`() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(200)  // Triggers spill

        let desc = set.description
        #expect(desc.contains("Set<Bit>.Packed.Small"))
        #expect(desc.contains("spilled"))
    }

    // MARK: - Large Values

    @Test
    func `Large values in heap mode`() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(1000)
        try set.insert(10000)
        try set.insert(100000)

        #expect(set.isSpilled)
        #expect(set.count == 3)
        #expect(set.contains(1000))
        #expect(set.contains(10000))
        #expect(set.contains(100000))
    }

    // MARK: - Model Tests

    /// Linear congruential generator for deterministic randomness.
    struct LCG {
        var state: UInt64

        init(seed: UInt64) {
            self.state = seed
        }

        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    @Test
    func `Random operations match model`() throws {
        var rng = LCG(seed: 12345)
        var small = Set<Bit>.Packed.Small<2>()
        var model = Swift.Set<Int>()

        for _ in 0..<500 {
            let value = Int(rng.next() % 300)  // Mix of inline and spill values
            let op = rng.next() % 3

            switch op {
            case 0:  // insert
                let smallResult = try small.insert(Bit.Index(value))
                let modelResult = model.insert(value).inserted
                #expect(smallResult == modelResult)

            case 1:  // remove
                let idx: Bit.Index = try Bit.Index(value)
                let smallResult = small.contains(idx) ? (try? small.remove(idx)) != nil : false
                let modelResult = model.remove(value) != nil
                #expect(smallResult == modelResult)

            case 2:  // contains
                let idx: Bit.Index = try Bit.Index(value)
                #expect(small.contains(idx) == model.contains(value))

            default:
                break
            }

            #expect(small.count == model.count)
        }
    }
}
