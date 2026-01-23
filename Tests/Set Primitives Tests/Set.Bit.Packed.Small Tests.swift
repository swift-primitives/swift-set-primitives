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

@Suite("Set<Bit>.Packed.Small")
struct SetBitPackedSmallTests {

    // Helper to create Bit.Index from Int
    func idx(_ n: Int) -> Bit.Index {
        Bit.Index(__unchecked: (), position: n)
    }

    // MARK: - Basic Operations

    @Test("Init creates inline storage")
    func initCreatesInlineStorage() {
        let set = Set<Bit>.Packed.Small<2>()
        #expect(!set.isSpilled)
        #expect(set.isEmpty)
        #expect(set.count == 0)
        #expect(Set<Bit>.Packed.Small<2>.inlineCapacity == 128)
    }

    @Test("Insert within inline capacity")
    func insertWithinInlineCapacity() throws {
        var set = Set<Bit>.Packed.Small<2>()

        #expect(try set.insert(idx(0)) == true)
        #expect(try set.insert(idx(63)) == true)
        #expect(try set.insert(idx(64)) == true)
        #expect(try set.insert(idx(127)) == true)

        #expect(!set.isSpilled)
        #expect(set.count == 4)
        #expect(set.contains(idx(0)))
        #expect(set.contains(idx(63)))
        #expect(set.contains(idx(64)))
        #expect(set.contains(idx(127)))
    }

    @Test("Insert beyond inline capacity triggers spill")
    func insertBeyondInlineCapacityTriggersSpill() throws {
        var set = Set<Bit>.Packed.Small<2>()

        // Insert within inline capacity
        try set.insert(idx(0))
        try set.insert(idx(127))
        #expect(!set.isSpilled)

        // Insert beyond inline capacity
        try set.insert(idx(128))
        #expect(set.isSpilled)
        #expect(set.count == 3)

        // All elements still accessible
        #expect(set.contains(idx(0)))
        #expect(set.contains(idx(127)))
        #expect(set.contains(idx(128)))
    }

    @Test("Insert returns false for existing")
    func insertReturnsFalse() throws {
        var set = Set<Bit>.Packed.Small<2>()

        #expect(try set.insert(idx(42)) == true)
        #expect(try set.insert(idx(42)) == false)
    }

    @Test("Remove in inline mode")
    func removeInInlineMode() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(idx(10))
        try set.insert(idx(20))
        try set.insert(idx(30))

        #expect(try set.remove(idx(20)) == true)
        #expect(!set.contains(idx(20)))
        #expect(set.contains(idx(10)))
        #expect(set.contains(idx(30)))
        #expect(set.count == 2)
        #expect(!set.isSpilled)
    }

    @Test("Remove in heap mode")
    func removeInHeapMode() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(idx(10))
        try set.insert(idx(200))  // Triggers spill
        try set.insert(idx(300))

        #expect(set.isSpilled)

        #expect(try set.remove(idx(200)) == true)
        #expect(!set.contains(idx(200)))
        #expect(set.contains(idx(10)))
        #expect(set.contains(idx(300)))
        #expect(set.count == 2)
    }

    @Test("Negative element not contained")
    func negativeNotContained() {
        let set = Set<Bit>.Packed.Small<2>()
        #expect(!set.contains(idx(-1)))
        #expect(!set.contains(idx(-100)))
    }

    // MARK: - Clear and Reset

    @Test("Clear resets to inline mode")
    func clearResetsToInlineMode() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(idx(10))
        try set.insert(idx(200))  // Triggers spill
        #expect(set.isSpilled)

        set.clear()
        #expect(!set.isSpilled)
        #expect(set.isEmpty)
        #expect(set.count == 0)
        #expect(set.capacity == Set<Bit>.Packed.Small<2>.inlineCapacity)
    }

    @Test("RemoveAll keeps heap mode")
    func removeAllKeepsHeapMode() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(idx(10))
        try set.insert(idx(200))  // Triggers spill
        #expect(set.isSpilled)

        set.removeAll()
        #expect(set.isSpilled)  // Still in heap mode
        #expect(set.isEmpty)
        #expect(set.count == 0)
    }

    // MARK: - Properties

    @Test("Count in inline mode")
    func countInInlineMode() throws {
        var set = Set<Bit>.Packed.Small<2>()
        #expect(set.count == 0)

        try set.insert(idx(0))
        #expect(set.count == 1)

        try set.insert(idx(64))
        #expect(set.count == 2)

        try set.insert(idx(127))
        #expect(set.count == 3)
    }

    @Test("Count in heap mode")
    func countInHeapMode() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(idx(0))
        try set.insert(idx(200))  // Triggers spill
        try set.insert(idx(300))

        #expect(set.count == 3)
    }

    @Test("Min and max in inline mode")
    func minAndMaxInInlineMode() throws {
        var set = Set<Bit>.Packed.Small<2>()
        #expect(set.min == nil)
        #expect(set.max == nil)

        try set.insert(idx(50))
        #expect(set.min == idx(50))
        #expect(set.max == idx(50))

        try set.insert(idx(10))
        try set.insert(idx(90))
        #expect(set.min == idx(10))
        #expect(set.max == idx(90))
    }

    @Test("Min and max in heap mode")
    func minAndMaxInHeapMode() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(idx(10))
        try set.insert(idx(200))  // Triggers spill
        try set.insert(idx(1000))

        #expect(set.min == idx(10))
        #expect(set.max == idx(1000))
    }

    // MARK: - Iteration

    @Test("Iteration in inline mode")
    func iterationInInlineMode() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(idx(100))
        try set.insert(idx(10))
        try set.insert(idx(50))
        try set.insert(idx(1))

        let elements = Swift.Array(set)
        #expect(elements == [idx(1), idx(10), idx(50), idx(100)])
    }

    @Test("Iteration in heap mode")
    func iterationInHeapMode() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(idx(10))
        try set.insert(idx(200))  // Triggers spill
        try set.insert(idx(50))
        try set.insert(idx(300))

        let elements = Swift.Array(set)
        #expect(elements == [idx(10), idx(50), idx(200), idx(300)])
    }

    // MARK: - Set Algebra

    @Test("Union in inline mode")
    func unionInInlineMode() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(idx(1))
        try a.insert(idx(2))

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(idx(2))
        try b.insert(idx(3))

        let result = a.algebra.union(b)
        #expect(result.count == 3)
        #expect(result.contains(idx(1)))
        #expect(result.contains(idx(2)))
        #expect(result.contains(idx(3)))
    }

    @Test("Union triggers spill")
    func unionTriggersSpill() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(idx(1))

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(idx(200))  // Beyond inline capacity

        let result = a.algebra.union(b)
        #expect(result.isSpilled)
        #expect(result.count == 2)
        #expect(result.contains(idx(1)))
        #expect(result.contains(idx(200)))
    }

    @Test("Intersection")
    func intersection() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(idx(1))
        try a.insert(idx(2))
        try a.insert(idx(3))

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(idx(2))
        try b.insert(idx(3))
        try b.insert(idx(4))

        let result = a.algebra.intersection(b)
        #expect(result.count == 2)
        #expect(result.contains(idx(2)))
        #expect(result.contains(idx(3)))
        #expect(!result.contains(idx(1)))
        #expect(!result.contains(idx(4)))
    }

    @Test("Subtracting")
    func subtracting() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(idx(1))
        try a.insert(idx(2))
        try a.insert(idx(3))

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(idx(2))

        let result = a.algebra.subtract(b)
        #expect(result.count == 2)
        #expect(result.contains(idx(1)))
        #expect(result.contains(idx(3)))
        #expect(!result.contains(idx(2)))
    }

    @Test("Symmetric difference")
    func symmetricDifference() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(idx(1))
        try a.insert(idx(2))

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(idx(2))
        try b.insert(idx(3))

        let result = a.algebra.symmetric.difference(b)
        #expect(result.count == 2)
        #expect(result.contains(idx(1)))
        #expect(result.contains(idx(3)))
        #expect(!result.contains(idx(2)))
    }

    // MARK: - Set Relations

    @Test("isSubset")
    func isSubset() throws {
        var small = Set<Bit>.Packed.Small<2>()
        try small.insert(idx(1))
        try small.insert(idx(2))

        var large = Set<Bit>.Packed.Small<2>()
        try large.insert(idx(1))
        try large.insert(idx(2))
        try large.insert(idx(3))

        #expect(small.relation.isSubset(of: large))
        #expect(!large.relation.isSubset(of: small))
    }

    @Test("isSuperset")
    func isSuperset() throws {
        var small = Set<Bit>.Packed.Small<2>()
        try small.insert(idx(1))
        try small.insert(idx(2))

        var large = Set<Bit>.Packed.Small<2>()
        try large.insert(idx(1))
        try large.insert(idx(2))
        try large.insert(idx(3))

        #expect(large.relation.isSuperset(of: small))
        #expect(!small.relation.isSuperset(of: large))
    }

    @Test("isDisjoint")
    func isDisjoint() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(idx(1))
        try a.insert(idx(2))

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(idx(3))
        try b.insert(idx(4))

        var c = Set<Bit>.Packed.Small<2>()
        try c.insert(idx(2))
        try c.insert(idx(3))

        #expect(a.relation.isDisjoint(with: b))
        #expect(!a.relation.isDisjoint(with: c))
    }

    // MARK: - Equality

    @Test("Equality inline mode")
    func equalityInlineMode() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(idx(1))
        try a.insert(idx(2))

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(idx(1))
        try b.insert(idx(2))

        var c = Set<Bit>.Packed.Small<2>()
        try c.insert(idx(1))
        try c.insert(idx(3))

        #expect(a == b)
        #expect(a != c)
    }

    @Test("Equality heap mode")
    func equalityHeapMode() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(idx(1))
        try a.insert(idx(200))

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(idx(1))
        try b.insert(idx(200))

        #expect(a == b)
    }

    @Test("Equality mixed modes")
    func equalityMixedModes() throws {
        var a = Set<Bit>.Packed.Small<2>()
        try a.insert(idx(1))
        try a.insert(idx(2))

        var b = Set<Bit>.Packed.Small<2>()
        try b.insert(idx(1))
        try b.insert(idx(2))
        try b.insert(idx(200))  // Triggers spill
        try b.remove(idx(200))  // Remove but still in heap mode

        // Both have same elements even though different storage modes
        #expect(a == b)
    }

    // MARK: - Description

    @Test("Description inline mode")
    func descriptionInlineMode() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(idx(1))
        try set.insert(idx(2))

        let desc = set.description
        #expect(desc.contains("Set<Bit>.Packed.Small"))
        #expect(!desc.contains("spilled"))
    }

    @Test("Description heap mode")
    func descriptionHeapMode() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(idx(200))  // Triggers spill

        let desc = set.description
        #expect(desc.contains("Set<Bit>.Packed.Small"))
        #expect(desc.contains("spilled"))
    }

    // MARK: - Large Values

    @Test("Large values in heap mode")
    func largeValuesInHeapMode() throws {
        var set = Set<Bit>.Packed.Small<2>()
        try set.insert(idx(1000))
        try set.insert(idx(10000))
        try set.insert(idx(100000))

        #expect(set.isSpilled)
        #expect(set.count == 3)
        #expect(set.contains(idx(1000)))
        #expect(set.contains(idx(10000)))
        #expect(set.contains(idx(100000)))
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

    @Test("Random operations match model")
    func randomOperationsMatchModel() throws {
        var rng = LCG(seed: 12345)
        var small = Set<Bit>.Packed.Small<2>()
        var model = Swift.Set<Int>()

        for _ in 0..<500 {
            let value = Int(rng.next() % 300)  // Mix of inline and spill values
            let op = rng.next() % 3

            switch op {
            case 0:  // insert
                let smallResult = try small.insert(idx(value))
                let modelResult = model.insert(value).inserted
                #expect(smallResult == modelResult)

            case 1:  // remove
                let smallResult = small.contains(idx(value)) ? (try? small.remove(idx(value))) != nil : false
                let modelResult = model.remove(value) != nil
                #expect(smallResult == modelResult)

            case 2:  // contains
                #expect(small.contains(idx(value)) == model.contains(value))

            default:
                break
            }

            #expect(small.count == model.count)
        }
    }
}
