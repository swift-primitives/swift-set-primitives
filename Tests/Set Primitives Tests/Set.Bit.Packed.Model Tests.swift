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

@Suite("Set<Bit>.Packed - Model Tests")
struct SetBitPackedModelTests {

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

    // Helper to create Bit.Index from Int
    func idx(_ n: Int) -> Bit.Index {
        Bit.Index(__unchecked: (), position: n)
    }

    // Helper to convert Set<Bit>.Packed to Set<Int> for comparison
    func toIntSet(_ bitSet: Set<Bit>.Packed) -> SetModel {
        var result = SetModel()
        for index in bitSet {
            result.insert(index.position)
        }
        return result
    }

    @Test("Random operations match Swift.Set model")
    func randomOperationsMatchModel() throws {
        var rng = LCG(seed: 12345)
        var bitSet = Set<Bit>.Packed()
        var model = SetModel()

        for _ in 0..<1000 {
            let value = Int(rng.next() % 500)  // Range up to 500
            let op = rng.next() % 3

            switch op {
            case 0:  // insert
                let bitResult = try bitSet.insert(idx(value))
                let modelResult = model.insert(value).inserted
                #expect(bitResult == modelResult)

            case 1:  // remove
                let bitResult = bitSet.contains(idx(value)) ? (try? bitSet.remove(idx(value))) != nil : false
                let modelResult = model.remove(value) != nil
                #expect(bitResult == modelResult)

            case 2:  // contains
                #expect(bitSet.contains(idx(value)) == model.contains(value))

            default:
                break
            }

            // Verify count
            #expect(bitSet.count == model.count)
            #expect(bitSet.isEmpty == model.isEmpty)
        }

        // Final verification
        #expect(toIntSet(bitSet) == model)
    }

    @Test("Word boundary operations match model")
    func wordBoundaryOperationsMatchModel() throws {
        var bitSet = Set<Bit>.Packed()
        var model = SetModel()

        // Test around word boundaries (0, 63, 64, 127, 128)
        let boundaryValues = [0, 1, 62, 63, 64, 65, 126, 127, 128, 129, 191, 192]

        for value in boundaryValues {
            #expect(try bitSet.insert(idx(value)) == true)
            model.insert(value)
        }

        #expect(bitSet.count == model.count)

        for value in boundaryValues {
            #expect(bitSet.contains(idx(value)) == model.contains(value))
        }

        // Remove every other
        for (index, value) in boundaryValues.enumerated() where index % 2 == 0 {
            #expect((try? bitSet.remove(idx(value))) != nil)
            model.remove(value)
        }

        #expect(toIntSet(bitSet) == model)
    }

    @Test("Union matches model")
    func unionMatchesModel() throws {
        var rng = LCG(seed: 23456)

        var bitSetA = Set<Bit>.Packed()
        var bitSetB = Set<Bit>.Packed()
        var modelA = SetModel()
        var modelB = SetModel()

        for _ in 0..<100 {
            let valueA = Int(rng.next() % 200)
            let valueB = Int(rng.next() % 200)
            try bitSetA.insert(idx(valueA))
            try bitSetB.insert(idx(valueB))
            modelA.insert(valueA)
            modelB.insert(valueB)
        }

        let bitUnion = bitSetA.algebra.union(bitSetB)
        let modelUnion = modelA.union(modelB)

        #expect(toIntSet(bitUnion) == modelUnion)
    }

    @Test("Intersection matches model")
    func intersectionMatchesModel() throws {
        var rng = LCG(seed: 34567)

        var bitSetA = Set<Bit>.Packed()
        var bitSetB = Set<Bit>.Packed()
        var modelA = SetModel()
        var modelB = SetModel()

        for _ in 0..<100 {
            let valueA = Int(rng.next() % 100)
            let valueB = Int(rng.next() % 100)
            try bitSetA.insert(idx(valueA))
            try bitSetB.insert(idx(valueB))
            modelA.insert(valueA)
            modelB.insert(valueB)
        }

        let bitIntersection = bitSetA.algebra.intersection(bitSetB)
        let modelIntersection = modelA.intersection(modelB)

        #expect(toIntSet(bitIntersection) == modelIntersection)
    }

    @Test("Subtracting matches model")
    func subtractingMatchesModel() throws {
        var rng = LCG(seed: 45678)

        var bitSetA = Set<Bit>.Packed()
        var bitSetB = Set<Bit>.Packed()
        var modelA = SetModel()
        var modelB = SetModel()

        for _ in 0..<100 {
            let valueA = Int(rng.next() % 100)
            let valueB = Int(rng.next() % 100)
            try bitSetA.insert(idx(valueA))
            try bitSetB.insert(idx(valueB))
            modelA.insert(valueA)
            modelB.insert(valueB)
        }

        let bitDifference = bitSetA.algebra.subtract(bitSetB)
        let modelDifference = modelA.subtracting(modelB)

        #expect(toIntSet(bitDifference) == modelDifference)
    }

    @Test("Symmetric difference matches model")
    func symmetricDifferenceMatchesModel() throws {
        var rng = LCG(seed: 56789)

        var bitSetA = Set<Bit>.Packed()
        var bitSetB = Set<Bit>.Packed()
        var modelA = SetModel()
        var modelB = SetModel()

        for _ in 0..<100 {
            let valueA = Int(rng.next() % 100)
            let valueB = Int(rng.next() % 100)
            try bitSetA.insert(idx(valueA))
            try bitSetB.insert(idx(valueB))
            modelA.insert(valueA)
            modelB.insert(valueB)
        }

        let bitSymmetric = bitSetA.algebra.symmetric.difference(bitSetB)
        let modelSymmetric = modelA.symmetricDifference(modelB)

        #expect(toIntSet(bitSymmetric) == modelSymmetric)
    }

    @Test("isSubset matches model")
    func isSubsetMatchesModel() throws {
        var bitSetA = Set<Bit>.Packed()
        var bitSetB = Set<Bit>.Packed()
        var modelA = SetModel()
        var modelB = SetModel()

        // A is subset of B
        for i in 0..<10 {
            try bitSetA.insert(idx(i))
            modelA.insert(i)
        }
        for i in 0..<20 {
            try bitSetB.insert(idx(i))
            modelB.insert(i)
        }

        #expect(bitSetA.relation.isSubset(of: bitSetB) == modelA.isSubset(of: modelB))
        #expect(bitSetB.relation.isSubset(of: bitSetA) == modelB.isSubset(of: modelA))

        // Add element not in B
        try bitSetA.insert(idx(100))
        modelA.insert(100)
        #expect(bitSetA.relation.isSubset(of: bitSetB) == modelA.isSubset(of: modelB))
    }

    @Test("isSuperset matches model")
    func isSupersetMatchesModel() throws {
        var bitSetA = Set<Bit>.Packed()
        var bitSetB = Set<Bit>.Packed()
        var modelA = SetModel()
        var modelB = SetModel()

        for i in 0..<20 {
            try bitSetA.insert(idx(i))
            modelA.insert(i)
        }
        for i in 0..<10 {
            try bitSetB.insert(idx(i))
            modelB.insert(i)
        }

        #expect(bitSetA.relation.isSuperset(of: bitSetB) == modelA.isSuperset(of: modelB))
        #expect(bitSetB.relation.isSuperset(of: bitSetA) == modelB.isSuperset(of: modelA))
    }

    @Test("isDisjoint matches model")
    func isDisjointMatchesModel() throws {
        var bitSetA = Set<Bit>.Packed()
        var bitSetB = Set<Bit>.Packed()
        var modelA = SetModel()
        var modelB = SetModel()

        // Disjoint
        for i in 0..<10 {
            try bitSetA.insert(idx(i))
            modelA.insert(i)
        }
        for i in 10..<20 {
            try bitSetB.insert(idx(i))
            modelB.insert(i)
        }

        #expect(bitSetA.relation.isDisjoint(with: bitSetB) == modelA.isDisjoint(with: modelB))

        // Not disjoint
        try bitSetA.insert(idx(15))
        modelA.insert(15)
        #expect(bitSetA.relation.isDisjoint(with: bitSetB) == modelA.isDisjoint(with: modelB))
    }

    @Test("Min and max match model")
    func minAndMaxMatchModel() throws {
        var rng = LCG(seed: 67890)
        var bitSet = Set<Bit>.Packed()
        var model = SetModel()

        for _ in 0..<100 {
            let value = Int(rng.next() % 1000)
            try bitSet.insert(idx(value))
            model.insert(value)
        }

        #expect(bitSet.min?.position == model.min())
        #expect(bitSet.max?.position == model.max())
    }

    @Test("Iteration produces sorted elements")
    func iterationProducesSortedElements() throws {
        var rng = LCG(seed: 78901)
        var bitSet = Set<Bit>.Packed()

        for _ in 0..<100 {
            try bitSet.insert(idx(Int(rng.next() % 500)))
        }

        let elements = Swift.Array(bitSet).map { $0.position }

        // Should be sorted
        #expect(elements == elements.sorted())

        // Should match count
        #expect(elements.count == bitSet.count)
    }

    @Test("Large sparse set matches model")
    func largeSparseSetMatchesModel() throws {
        var rng = LCG(seed: 89012)
        var bitSet = Set<Bit>.Packed()
        var model = SetModel()

        // Insert sparse values across a wide range
        for _ in 0..<50 {
            let value = Int(rng.next() % 100000)
            try bitSet.insert(idx(value))
            model.insert(value)
        }

        #expect(bitSet.count == model.count)
        #expect(toIntSet(bitSet) == model)

        // Remove some
        for _ in 0..<25 {
            let value = Int(rng.next() % 100000)
            if bitSet.contains(idx(value)) {
                try bitSet.remove(idx(value))
            }
            model.remove(value)
        }

        #expect(toIntSet(bitSet) == model)
    }

    @Test("Heavy insert/remove cycles")
    func heavyInsertRemoveCycles() throws {
        var rng = LCG(seed: 90123)
        var bitSet = Set<Bit>.Packed()
        var model = SetModel()

        for cycle in 0..<10 {
            // Insert phase
            for _ in 0..<100 {
                let value = Int(rng.next() % 200)
                try bitSet.insert(idx(value))
                model.insert(value)
            }

            #expect(toIntSet(bitSet) == model, "Mismatch after insert phase \(cycle)")

            // Remove phase
            for _ in 0..<50 {
                let value = Int(rng.next() % 200)
                if bitSet.contains(idx(value)) {
                    try bitSet.remove(idx(value))
                }
                model.remove(value)
            }

            #expect(toIntSet(bitSet) == model, "Mismatch after remove phase \(cycle)")
        }
    }
}
