// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Set_Primitives_Test_Support
import Testing

@testable import Set_Primitives

// MARK: - Invariant Verification Helpers

/// Verifies all invariants of a Set.Ordered
func verifyInvariants<Element: Hashable>(
    _ set: borrowing Set<Element>.Ordered,
    expectedElements: [Element],
    file: StaticString = #file,
    line: UInt = #line
) {
    // Invariant 1: Count matches expected
    let count = Int(bitPattern: set.count)
    #expect(
        count == expectedElements.count,
        "Count mismatch: got \(count), expected \(expectedElements.count)",
        sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 0)
    )

    // Invariant 2: isEmpty is consistent with count
    let isEmpty = set.isEmpty
    #expect(
        isEmpty == (count == 0),
        "isEmpty inconsistent with count",
        sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 0)
    )

    // Invariant 3: Elements at indices match expected order
    for i in 0..<expectedElements.count {
        let idx = Index<Element>(_unchecked: Ordinal(UInt(i)))
        #expect(
            set[idx] == expectedElements[i],
            "Element at index \(i) mismatch",
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 0)
        )
    }

    // Invariant 4: index() returns correct position for each element
    for (i, element) in expectedElements.enumerated() {
        let foundIndex = set.index(element)
        let foundInt = foundIndex.map { Int(bitPattern: $0.position) }
        #expect(
            foundInt == i,
            "index(\(element)) returned \(String(describing: foundInt)), expected \(i)",
            sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 0)
        )
    }

    // Invariant 5: contains() returns true for all elements
    for element in expectedElements {
        let contains = set.contains(element)
        #expect(contains, "contains(\(element)) returned false", sourceLocation: SourceLocation(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 0))
    }
}

@Suite("Set.Ordered - Model Tests")
struct OrderedSetModelTests {

    /// Linear congruential generator for deterministic randomness.
    struct LCG {
        var state: UInt64

        init(seed: UInt64) {
            self.state = seed
        }

        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }

        mutating func nextInt(_ bound: Int) -> Int {
            Int(next() % UInt64(bound))
        }

        mutating func nextBool() -> Bool {
            next() % 2 == 0
        }
    }

    /// Reference model using Array + Set for comparison.
    struct ArraySetModel<Element: Hashable> {
        var elements: [Element] = []
        var set: Swift.Set<Element> = []

        var count: Int { elements.count }
        var isEmpty: Bool { elements.isEmpty }

        func contains(_ element: Element) -> Bool {
            set.contains(element)
        }

        func index(_ element: Element) -> Int? {
            elements.firstIndex(of: element)
        }

        @discardableResult
        mutating func insert(_ element: Element) -> (inserted: Bool, index: Int) {
            if let existing = elements.firstIndex(of: element) {
                return (false, existing)
            }
            elements.append(element)
            set.insert(element)
            return (true, elements.endIndex - 1)
        }

        @discardableResult
        mutating func remove(_ element: Element) -> Element? {
            guard let index = elements.firstIndex(of: element) else { return nil }
            set.remove(element)
            return elements.remove(at: index)
        }
    }

    // MARK: - Random Operations with Invariant Verification

    @Test
    func `Random operations match model - 1000 iterations`() {
        var rng = LCG(seed: 33333)
        var orderedSet = Set<Int>.Ordered()
        var model = ArraySetModel<Int>()

        for iteration in 0..<1000 {
            let value = rng.nextInt(100)  // Limited range to ensure collisions
            let op = rng.nextInt(4)

            switch op {
            case 0:  // insert
                let orderedResult = orderedSet.insert(value)
                let modelResult = model.insert(value)
                #expect(orderedResult.inserted == modelResult.inserted, "Insert mismatch at iteration \(iteration)")
                #expect(Int(bitPattern: orderedResult.index.position) == modelResult.index, "Insert index mismatch at iteration \(iteration)")

            case 1:  // remove
                let orderedResult = orderedSet.remove(value)
                let modelResult = model.remove(value)
                #expect(orderedResult == modelResult, "Remove mismatch at iteration \(iteration)")

            case 2:  // contains
                let orderedContains = orderedSet.contains(value)
                let modelContains = model.contains(value)
                #expect(orderedContains == modelContains, "Contains mismatch at iteration \(iteration)")

            case 3:  // index
                let orderedIndex = orderedSet.index(value).map { Int(bitPattern: $0.position) }
                let modelIndex = model.index(value)
                #expect(orderedIndex == modelIndex, "Index mismatch at iteration \(iteration)")

            default:
                break
            }

            // Verify count invariant after each operation
            let setCount = Int(bitPattern: orderedSet.count)
            let modelCount = model.count
            #expect(setCount == modelCount, "Count mismatch after iteration \(iteration)")

            let setIsEmpty = orderedSet.isEmpty
            let modelIsEmpty = model.isEmpty
            #expect(setIsEmpty == modelIsEmpty, "isEmpty mismatch after iteration \(iteration)")
        }

        // Final verification: all elements match
        let finalArray = toArray(orderedSet)
        #expect(finalArray == model.elements, "Final elements mismatch")
    }

    // MARK: - Order Preservation Invariants

    @Test
    func `Insertion order strictly preserved`() {
        var rng = LCG(seed: 44444)
        var orderedSet = Set<Int>.Ordered()
        var model = ArraySetModel<Int>()

        var inserted: [Int] = []
        for _ in 0..<500 {
            let value = rng.nextInt(10000)
            if !model.contains(value) {
                orderedSet.insert(value)
                model.insert(value)
                inserted.append(value)
            }
        }

        // Verify order invariant
        let array = toArray(orderedSet)
        #expect(array == inserted, "Insertion order not preserved")
        #expect(array == model.elements, "Elements don't match model")

        // Verify index invariant for all elements
        for (i, element) in inserted.enumerated() {
            let foundIndex = orderedSet.index(element).map { Int(bitPattern: $0.position) }
            #expect(foundIndex == i, "Index invariant violated for element \(element)")
        }
    }

    @Test
    func `Remove maintains order of remaining elements`() {
        var rng = LCG(seed: 55555)
        var orderedSet = Set<Int>.Ordered()
        var model = ArraySetModel<Int>()

        // Insert 200 elements
        for i in 0..<200 {
            orderedSet.insert(i)
            model.insert(i)
        }

        // Remove 100 random elements
        for _ in 0..<100 {
            let value = rng.nextInt(200)
            orderedSet.remove(value)
            model.remove(value)
        }

        let array = toArray(orderedSet)
        #expect(array == model.elements, "Order not maintained after removals")

        // Verify index invariant for remaining elements
        for (idx, element) in array.enumerated() {
            let foundIndex = orderedSet.index(element)
            let modelIndex = model.index(element)
            #expect(foundIndex.map { Int(bitPattern: $0.position) } == idx, "Set index invariant violated")
            #expect(modelIndex == idx, "Model index mismatch")
        }
    }

    // MARK: - Set Algebra Invariants

    @Test
    func `Algebra union matches model`() {
        var rng = LCG(seed: 66666)

        var setA = Set<Int>.Ordered()
        var setB = Set<Int>.Ordered()
        var modelA = ArraySetModel<Int>()
        var modelB = ArraySetModel<Int>()

        for _ in 0..<100 {
            let valueA = rng.nextInt(100)
            let valueB = rng.nextInt(100)
            setA.insert(valueA)
            setB.insert(valueB)
            modelA.insert(valueA)
            modelB.insert(valueB)
        }

        let union = setA.algebra.union(setB)

        // Model union: all from A, then new from B
        var modelUnion = modelA
        for element in modelB.elements {
            modelUnion.insert(element)
        }

        let unionCount = Int(bitPattern: union.count)
        #expect(unionCount == modelUnion.count, "Union count mismatch")

        let unionArray = toArray(union)
        #expect(unionArray == modelUnion.elements, "Union elements mismatch")
    }

    @Test
    func `Algebra intersection matches model`() {
        var rng = LCG(seed: 77777)

        var setA = Set<Int>.Ordered()
        var setB = Set<Int>.Ordered()

        for _ in 0..<200 {
            setA.insert(rng.nextInt(50))
            setB.insert(rng.nextInt(50))
        }

        let intersection = setA.algebra.intersection(setB)

        // Model: elements in A that are also in B, maintaining A's order
        let arrayA = toArray(setA)
        let modelIntersection = arrayA.filter { setB.contains($0) }

        let intersectionArray = toArray(intersection)
        #expect(intersectionArray == modelIntersection, "Intersection mismatch")
    }

    @Test
    func `Algebra subtract matches model`() {
        var rng = LCG(seed: 88888)

        var setA = Set<Int>.Ordered()
        var setB = Set<Int>.Ordered()

        for _ in 0..<200 {
            setA.insert(rng.nextInt(50))
            setB.insert(rng.nextInt(50))
        }

        let difference = setA.algebra.subtract(setB)

        let arrayA = toArray(setA)
        let modelDifference = arrayA.filter { !setB.contains($0) }

        let differenceArray = toArray(difference)
        #expect(differenceArray == modelDifference, "Subtract mismatch")
    }

    @Test
    func `Algebra symmetric difference matches model`() {
        var rng = LCG(seed: 99999)

        var setA = Set<Int>.Ordered()
        var setB = Set<Int>.Ordered()

        for _ in 0..<200 {
            setA.insert(rng.nextInt(50))
            setB.insert(rng.nextInt(50))
        }

        let symmetric = setA.algebra.symmetric.difference(setB)

        // Model: (A - B) union (B - A), with A's elements first
        let arrayA = toArray(setA)
        let arrayB = toArray(setB)
        let onlyA = arrayA.filter { !setB.contains($0) }
        let onlyB = arrayB.filter { !setA.contains($0) }
        let modelSymmetric = onlyA + onlyB

        let symmetricArray = toArray(symmetric)
        #expect(symmetricArray == modelSymmetric, "Symmetric difference mismatch")
    }

    // MARK: - Index Access Invariants

    @Test
    func `Index access matches model`() {
        var rng = LCG(seed: 10101)
        var orderedSet = Set<Int>.Ordered()
        var model = ArraySetModel<Int>()

        for _ in 0..<200 {
            let value = rng.nextInt(1000)
            orderedSet.insert(value)
            model.insert(value)
        }

        // Verify all indices
        let count = orderedSet.count
        let countInt = Int(bitPattern: count)
        for i in 0..<countInt {
            let idx = Index<Int>(_unchecked: Ordinal(UInt(i)))
            #expect(orderedSet[idx] == model.elements[i], "Index \(i) mismatch")
        }

        // Random access verification
        for _ in 0..<100 {
            let i = rng.nextInt(countInt)
            let idx = Index<Int>(_unchecked: Ordinal(UInt(i)))
            #expect(orderedSet[idx] == model.elements[i], "Random access mismatch at \(i)")
        }
    }

    // MARK: - Heavy Operations

    @Test
    func `Heavy insert/remove cycles`() {
        var rng = LCG(seed: 20202)
        var orderedSet = Set<Int>.Ordered()
        var model = ArraySetModel<Int>()

        for cycle in 0..<5 {
            // Insert phase
            for _ in 0..<100 {
                let value = rng.nextInt(200)
                orderedSet.insert(value)
                model.insert(value)
            }

            let insertArray = toArray(orderedSet)
            #expect(insertArray == model.elements, "Mismatch after insert phase \(cycle)")

            // Remove phase
            for _ in 0..<50 {
                let value = rng.nextInt(200)
                orderedSet.remove(value)
                model.remove(value)
            }

            let removeArray = toArray(orderedSet)
            #expect(removeArray == model.elements, "Mismatch after remove phase \(cycle)")
        }
    }

    @Test
    func `Large set operations`() {
        var setA = Set<Int>.Ordered()
        var setB = Set<Int>.Ordered()

        // Build large sets with known overlap
        for i in 0..<1000 {
            setA.insert(i)
        }
        for i in 500..<1500 {
            setB.insert(i)
        }

        let union = setA.algebra.union(setB)
        let unionCount = union.count
        #expect(unionCount == 1500, "Union should have 1500 elements (0-1499)")

        let intersection = setA.algebra.intersection(setB)
        let intersectionCount = intersection.count
        #expect(intersectionCount == 500, "Intersection should have 500 elements (500-999)")

        let difference = setA.algebra.subtract(setB)
        let differenceCount = difference.count
        #expect(differenceCount == 500, "Difference should have 500 elements (0-499)")

        let symmetric = setA.algebra.symmetric.difference(setB)
        let symmetricCount = symmetric.count
        #expect(symmetricCount == 1000, "Symmetric difference should have 1000 elements (0-499 and 1000-1499)")
    }

    // MARK: - Edge Cases

    @Test
    func `Empty set operations`() {
        let empty = Set<Int>.Ordered()
        var nonEmpty = Set<Int>.Ordered()
        nonEmpty.insert(1)
        nonEmpty.insert(2)
        nonEmpty.insert(3)

        // Union with empty
        let unionEmptyFirst = toArray(empty.algebra.union(nonEmpty))
        let unionEmptySecond = toArray(nonEmpty.algebra.union(empty))
        #expect(unionEmptyFirst == [1, 2, 3], "Union with empty (empty first)")
        #expect(unionEmptySecond == [1, 2, 3], "Union with empty (empty second)")

        // Intersection with empty
        let intersectionEmpty = empty.algebra.intersection(nonEmpty)
        let intersectionNonEmpty = nonEmpty.algebra.intersection(empty)
        let intersectionEmptyIsEmpty = intersectionEmpty.isEmpty
        let intersectionNonEmptyIsEmpty = intersectionNonEmpty.isEmpty
        #expect(intersectionEmptyIsEmpty, "Intersection with empty should be empty")
        #expect(intersectionNonEmptyIsEmpty, "Intersection with empty should be empty")

        // Subtract empty
        let subtractEmpty = toArray(nonEmpty.algebra.subtract(empty))
        let subtractFromEmpty = empty.algebra.subtract(nonEmpty)
        let subtractFromEmptyIsEmpty = subtractFromEmpty.isEmpty
        #expect(subtractEmpty == [1, 2, 3], "Subtract empty should preserve elements")
        #expect(subtractFromEmptyIsEmpty, "Subtract from empty should be empty")
    }

    @Test
    func `Single element set operations`() {
        var set = Set<Int>.Ordered()
        set.insert(42)

        let contains42 = set.contains(42)
        let contains0 = set.contains(0)
        let index42 = set.index(42)
        let index0 = set.index(0)
        let count = set.count
        #expect(contains42, "Should contain 42")
        #expect(!contains0, "Should not contain 0")
        #expect(index42 == 0, "Index of 42 should be 0")
        #expect(index0 == nil, "Index of 0 should be nil")
        #expect(count == 1, "Count should be 1")

        set.remove(42)
        let isEmptyAfterRemove = set.isEmpty
        let contains42AfterRemove = set.contains(42)
        #expect(isEmptyAfterRemove, "Should be empty after remove")
        #expect(!contains42AfterRemove, "Should not contain 42 after remove")
    }

    @Test
    func `Duplicate insert behavior`() {
        var orderedSet = Set<Int>.Ordered()
        var model = ArraySetModel<Int>()

        // First insert
        let first = orderedSet.insert(42)
        let modelFirst = model.insert(42)
        #expect(first.inserted == modelFirst.inserted, "First insert: inserted flag mismatch")
        #expect(first.inserted == true, "First insert should succeed")
        #expect(first.index == 0, "First insert index should be 0")

        // Duplicate insert
        let second = orderedSet.insert(42)
        let modelSecond = model.insert(42)
        #expect(second.inserted == modelSecond.inserted, "Duplicate insert: inserted flag mismatch")
        #expect(second.inserted == false, "Duplicate insert should fail")
        #expect(second.index == 0, "Duplicate insert should return existing index")

        let count = orderedSet.count
        #expect(count == 1, "Count should still be 1 after duplicate insert")
    }

    // MARK: - Hash.Protocol Invariants

    @Test
    func `Equal sets have equal hash values`() {
        var rng = LCG(seed: 12345)

        for _ in 0..<10 {
            var setA = Set<Int>.Ordered()
            var setB = Set<Int>.Ordered()

            // Insert same elements in same order
            for _ in 0..<50 {
                let value = rng.nextInt(1000)
                setA.insert(value)
                setB.insert(value)
            }

            let equal = setA == setB
            #expect(equal, "Sets with same elements should be equal")

            let hashA = setA.hashValue
            let hashB = setB.hashValue
            #expect(hashA == hashB, "Equal sets should have equal hash values")
        }
    }

    @Test
    func `Different order produces different sets`() {
        var setA = Set<Int>.Ordered()
        setA.insert(1)
        setA.insert(2)
        setA.insert(3)

        var setB = Set<Int>.Ordered()
        setB.insert(3)
        setB.insert(2)
        setB.insert(1)

        let equal = setA == setB
        #expect(!equal, "Sets with different order should not be equal")
    }
}
