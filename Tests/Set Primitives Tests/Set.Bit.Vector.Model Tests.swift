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

@Suite("Set<Bit>.Vector - Model Tests")
struct SetBitVectorModelTests {

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

    /// Reference model using Swift.Set<Int> for comparison.
    typealias SetModel = Swift.Set<Int>

    @Test
    func `Random operations match Swift.Set model`() throws {
        var rng = LCG(seed: 12345)
        var bitSet = Set<Bit>.Vector()
        var model = SetModel()

        for _ in 0..<1000 {
            let value = Int(rng.next() % 500)  // Range up to 500
            let op = rng.next() % 3

            switch op {
            case 0:  // insert
                let bitResult = try bitSet.insert(Bit.Index(value))
                let modelResult = model.insert(value).inserted
                #expect(bitResult == modelResult)

            case 1:  // remove
                let idx = try Bit.Index(value)
                let bitResult = bitSet.contains(idx) ? (try? bitSet.remove(idx)) != nil : false
                let modelResult = model.remove(value) != nil
                #expect(bitResult == modelResult)

            case 2:  // contains
                let idx = try Bit.Index(value)
                #expect(bitSet.contains(idx) == model.contains(value))

            default:
                break
            }

            // Verify count
            #expect(bitSet.count == model.count)
            #expect(bitSet.isEmpty == model.isEmpty)
        }

        // Final verification - convert bitSet to Set<Int> for comparison
        var bitSetAsInts = SetModel()
        for index in bitSet {
            bitSetAsInts.insert(Int(bitPattern: index.position))
        }
        #expect(bitSetAsInts == model)
    }

    @Test
    func `Word boundary operations match model`() throws {
        var bitSet = Set<Bit>.Vector()
        var model = SetModel()

        // Test around word boundaries (0, 63, 64, 127, 128)
        let boundaryValues = [0, 1, 62, 63, 64, 65, 126, 127, 128, 129, 191, 192]

        for value in boundaryValues {
            #expect(try bitSet.insert(Bit.Index(value)) == true)
            model.insert(value)
        }

        #expect(bitSet.count == model.count)

        for value in boundaryValues {
            let idx = try Bit.Index(value)
            #expect(bitSet.contains(idx) == model.contains(value))
        }

        // Remove every other
        for (index, value) in boundaryValues.enumerated() where index % 2 == 0 {
            let idx = try Bit.Index(value)
            #expect((try? bitSet.remove(idx)) != nil)
            model.remove(value)
        }

        var bitSetAsInts = SetModel()
        for index in bitSet {
            bitSetAsInts.insert(Int(bitPattern: index.position))
        }
        #expect(bitSetAsInts == model)
    }

    @Test
    func `Union matches model`() throws {
        var rng = LCG(seed: 23456)

        var bitSetA = Set<Bit>.Vector()
        var bitSetB = Set<Bit>.Vector()
        var modelA = SetModel()
        var modelB = SetModel()

        for _ in 0..<100 {
            let valueA = Int(rng.next() % 200)
            let valueB = Int(rng.next() % 200)
            try bitSetA.insert(Bit.Index(valueA))
            try bitSetB.insert(Bit.Index(valueB))
            modelA.insert(valueA)
            modelB.insert(valueB)
        }

        let bitUnion = bitSetA.algebra.union(bitSetB)
        let modelUnion = modelA.union(modelB)

        var bitUnionAsInts = SetModel()
        for index in bitUnion {
            bitUnionAsInts.insert(Int(bitPattern: index.position))
        }
        #expect(bitUnionAsInts == modelUnion)
    }

    @Test
    func `Intersection matches model`() throws {
        var rng = LCG(seed: 34567)

        var bitSetA = Set<Bit>.Vector()
        var bitSetB = Set<Bit>.Vector()
        var modelA = SetModel()
        var modelB = SetModel()

        for _ in 0..<100 {
            let valueA = Int(rng.next() % 100)
            let valueB = Int(rng.next() % 100)
            try bitSetA.insert(Bit.Index(valueA))
            try bitSetB.insert(Bit.Index(valueB))
            modelA.insert(valueA)
            modelB.insert(valueB)
        }

        let bitIntersection = bitSetA.algebra.intersection(bitSetB)
        let modelIntersection = modelA.intersection(modelB)

        var bitIntersectionAsInts = SetModel()
        for index in bitIntersection {
            bitIntersectionAsInts.insert(Int(bitPattern: index.position))
        }
        #expect(bitIntersectionAsInts == modelIntersection)
    }

    @Test
    func `Subtracting matches model`() throws {
        var rng = LCG(seed: 45678)

        var bitSetA = Set<Bit>.Vector()
        var bitSetB = Set<Bit>.Vector()
        var modelA = SetModel()
        var modelB = SetModel()

        for _ in 0..<100 {
            let valueA = Int(rng.next() % 100)
            let valueB = Int(rng.next() % 100)
            try bitSetA.insert(Bit.Index(valueA))
            try bitSetB.insert(Bit.Index(valueB))
            modelA.insert(valueA)
            modelB.insert(valueB)
        }

        let bitDifference = bitSetA.algebra.subtract(bitSetB)
        let modelDifference = modelA.subtracting(modelB)

        var bitDifferenceAsInts = SetModel()
        for index in bitDifference {
            bitDifferenceAsInts.insert(Int(bitPattern: index.position))
        }
        #expect(bitDifferenceAsInts == modelDifference)
    }

    @Test
    func `Symmetric difference matches model`() throws {
        var rng = LCG(seed: 56789)

        var bitSetA = Set<Bit>.Vector()
        var bitSetB = Set<Bit>.Vector()
        var modelA = SetModel()
        var modelB = SetModel()

        for _ in 0..<100 {
            let valueA = Int(rng.next() % 100)
            let valueB = Int(rng.next() % 100)
            try bitSetA.insert(Bit.Index(valueA))
            try bitSetB.insert(Bit.Index(valueB))
            modelA.insert(valueA)
            modelB.insert(valueB)
        }

        let bitSymmetric = bitSetA.algebra.symmetric.difference(bitSetB)
        let modelSymmetric = modelA.symmetricDifference(modelB)

        var bitSymmetricAsInts = SetModel()
        for index in bitSymmetric {
            bitSymmetricAsInts.insert(Int(bitPattern: index.position))
        }
        #expect(bitSymmetricAsInts == modelSymmetric)
    }

    @Test
    func `isSubset matches model`() throws {
        var bitSetA = Set<Bit>.Vector()
        var bitSetB = Set<Bit>.Vector()
        var modelA = SetModel()
        var modelB = SetModel()

        // A is subset of B
        for i in 0..<10 {
            try bitSetA.insert(Bit.Index(i))
            modelA.insert(i)
        }
        for i in 0..<20 {
            try bitSetB.insert(Bit.Index(i))
            modelB.insert(i)
        }

        #expect(bitSetA.relation.isSubset(of: bitSetB) == modelA.isSubset(of: modelB))
        #expect(bitSetB.relation.isSubset(of: bitSetA) == modelB.isSubset(of: modelA))

        // Add element not in B
        try bitSetA.insert(100)
        modelA.insert(100)
        #expect(bitSetA.relation.isSubset(of: bitSetB) == modelA.isSubset(of: modelB))
    }

    @Test
    func `isSuperset matches model`() throws {
        var bitSetA = Set<Bit>.Vector()
        var bitSetB = Set<Bit>.Vector()
        var modelA = SetModel()
        var modelB = SetModel()

        for i in 0..<20 {
            try bitSetA.insert(Bit.Index(i))
            modelA.insert(i)
        }
        for i in 0..<10 {
            try bitSetB.insert(Bit.Index(i))
            modelB.insert(i)
        }

        #expect(bitSetA.relation.isSuperset(of: bitSetB) == modelA.isSuperset(of: modelB))
        #expect(bitSetB.relation.isSuperset(of: bitSetA) == modelB.isSuperset(of: modelA))
    }

    @Test
    func `isDisjoint matches model`() throws {
        var bitSetA = Set<Bit>.Vector()
        var bitSetB = Set<Bit>.Vector()
        var modelA = SetModel()
        var modelB = SetModel()

        // Disjoint
        for i in 0..<10 {
            try bitSetA.insert(Bit.Index(i))
            modelA.insert(i)
        }
        for i in 10..<20 {
            try bitSetB.insert(Bit.Index(i))
            modelB.insert(i)
        }

        #expect(bitSetA.relation.isDisjoint(with: bitSetB) == modelA.isDisjoint(with: modelB))

        // Not disjoint
        try bitSetA.insert(15)
        modelA.insert(15)
        #expect(bitSetA.relation.isDisjoint(with: bitSetB) == modelA.isDisjoint(with: modelB))
    }

    @Test
    func `Min and max match model`() throws {
        var rng = LCG(seed: 67890)
        var bitSet = Set<Bit>.Vector()
        var model = SetModel()

        for _ in 0..<100 {
            let value = Int(rng.next() % 1000)
            try bitSet.insert(Bit.Index(value))
            model.insert(value)
        }

        #expect(bitSet.min.map { Int(bitPattern: $0.position) } == model.min())
        #expect(bitSet.max.map { Int(bitPattern: $0.position) } == model.max())
    }

    @Test
    func `Iteration produces sorted elements`() throws {
        var rng = LCG(seed: 78901)
        var bitSet = Set<Bit>.Vector()

        for _ in 0..<100 {
            try bitSet.insert(Bit.Index(Int(rng.next() % 500)))
        }

        let elements = Swift.Array(bitSet).map { Int(bitPattern: $0.position) }

        // Should be sorted
        #expect(elements == elements.sorted())

        // Should match count
        #expect(elements.count == bitSet.count)
    }

    @Test
    func `Large sparse set matches model`() throws {
        var rng = LCG(seed: 89012)
        var bitSet = Set<Bit>.Vector()
        var model = SetModel()

        // Insert sparse values across a wide range
        for _ in 0..<50 {
            let value = Int(rng.next() % 100000)
            try bitSet.insert(Bit.Index(value))
            model.insert(value)
        }

        #expect(bitSet.count == model.count)

        var bitSetAsInts = SetModel()
        for index in bitSet {
            bitSetAsInts.insert(Int(bitPattern: index.position))
        }
        #expect(bitSetAsInts == model)

        // Remove some
        for _ in 0..<25 {
            let value = Int(rng.next() % 100000)
            let idx = try Bit.Index(value)
            if bitSet.contains(idx) {
                try bitSet.remove(idx)
            }
            model.remove(value)
        }

        bitSetAsInts = SetModel()
        for index in bitSet {
            bitSetAsInts.insert(Int(bitPattern: index.position))
        }
        #expect(bitSetAsInts == model)
    }

    @Test
    func `Heavy insert/remove cycles`() throws {
        var rng = LCG(seed: 90123)
        var bitSet = Set<Bit>.Vector()
        var model = SetModel()

        for cycle in 0..<10 {
            // Insert phase
            for _ in 0..<100 {
                let value = Int(rng.next() % 200)
                try bitSet.insert(Bit.Index(value))
                model.insert(value)
            }

            var bitSetAsInts = SetModel()
            for index in bitSet {
                bitSetAsInts.insert(Int(bitPattern: index.position))
            }
            #expect(bitSetAsInts == model, "Mismatch after insert phase \(cycle)")

            // Remove phase
            for _ in 0..<50 {
                let value = Int(rng.next() % 200)
                let idx = try Bit.Index(value)
                if bitSet.contains(idx) {
                    try bitSet.remove(idx)
                }
                model.remove(value)
            }

            bitSetAsInts = SetModel()
            for index in bitSet {
                bitSetAsInts.insert(Int(bitPattern: index.position))
            }
            #expect(bitSetAsInts == model, "Mismatch after remove phase \(cycle)")
        }
    }
}
