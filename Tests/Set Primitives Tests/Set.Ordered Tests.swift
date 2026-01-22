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

import Testing
@testable import Set_Primitives

// MARK: - Helper to convert Set.Ordered to Array

// Note: Set.Ordered is ~Copyable and cannot conform to Swift.Sequence.
// This helper uses index-based iteration to extract elements.
func toArray<Element: Hashable>(_ set: borrowing Set<Element>.Ordered) -> [Element] {
    var result: [Element] = []
    for i in 0..<set.count {
        result.append(set[i])
    }
    return result
}

@Suite("Set.Ordered")
struct OrderedSetTests {

    // MARK: - Basic Operations

    @Test("Insert and contains")
    func insertAndContains() {
        var set = Set<String>.Ordered()

        let (inserted1, index1) = set.insert("apple")
        #expect(inserted1)
        #expect(index1 == 0)

        let (inserted2, index2) = set.insert("banana")
        #expect(inserted2)
        #expect(index2 == 1)

        // Duplicate insert
        let (inserted3, index3) = set.insert("apple")
        #expect(!inserted3)
        #expect(index3 == 0)

        let containsApple = set.contains("apple")
        let containsBanana = set.contains("banana")
        let containsCherry = set.contains("cherry")
        #expect(containsApple)
        #expect(containsBanana)
        #expect(!containsCherry)
    }

    @Test("Index lookup")
    func indexLookup() {
        var set = Set<Int>.Ordered()
        set.insert(10)
        set.insert(20)
        set.insert(30)

        let index10 = set.index(10)
        let index20 = set.index(20)
        let index30 = set.index(30)
        let index40 = set.index(40)
        #expect(index10 == 0)
        #expect(index20 == 1)
        #expect(index30 == 2)
        #expect(index40 == nil)
    }

    @Test("Remove element")
    func removeElement() {
        var set = Set<Int>.Ordered()
        set.insert(1)
        set.insert(2)
        set.insert(3)
        set.insert(4)
        set.insert(5)

        let removed = set.remove(3)
        let count = set.count
        let contains3 = set.contains(3)
        #expect(removed == 3)
        #expect(count == 4)
        #expect(!contains3)

        // Indices should be updated
        let index4 = set.index(4)
        let index5 = set.index(5)
        #expect(index4 == 2)
        #expect(index5 == 3)

        // Remove non-existent
        let notRemoved = set.remove(100)
        #expect(notRemoved == nil)
    }

    // MARK: - Order Preservation

    @Test("Insertion order preserved")
    func insertionOrderPreserved() {
        var set = Set<String>.Ordered()
        set.insert("charlie")
        set.insert("alpha")
        set.insert("bravo")

        let array = toArray(set)
        #expect(array == ["charlie", "alpha", "bravo"])
    }

    @Test("Order after removal")
    func orderAfterRemoval() {
        var set = Set<Int>.Ordered()
        set.insert(1)
        set.insert(2)
        set.insert(3)
        set.insert(4)
        set.insert(5)
        set.remove(2)
        set.remove(4)

        let array = toArray(set)
        #expect(array == [1, 3, 5])
    }

    @Test("Re-insertion goes to end")
    func reinsertionGoesToEnd() {
        var set = Set<String>.Ordered()
        set.insert("a")
        set.insert("b")
        set.insert("c")
        set.remove("b")
        set.insert("b")

        let array = toArray(set)
        #expect(array == ["a", "c", "b"])
    }

    // MARK: - Algebra Operations

    @Test("Union")
    func union() {
        var a = Set<Int>.Ordered()
        a.insert(1)
        a.insert(2)
        a.insert(3)
        var b = Set<Int>.Ordered()
        b.insert(3)
        b.insert(4)
        b.insert(5)

        let result = a.algebra.union(b)
        let array = toArray(result)
        #expect(array == [1, 2, 3, 4, 5])
    }

    @Test("Intersection")
    func intersection() {
        var a = Set<Int>.Ordered()
        a.insert(1)
        a.insert(2)
        a.insert(3)
        a.insert(4)
        var b = Set<Int>.Ordered()
        b.insert(2)
        b.insert(4)
        b.insert(6)

        let result = a.algebra.intersection(b)
        let array = toArray(result)
        #expect(array == [2, 4])
    }

    @Test("Subtract")
    func subtract() {
        var a = Set<Int>.Ordered()
        a.insert(1)
        a.insert(2)
        a.insert(3)
        a.insert(4)
        a.insert(5)
        var b = Set<Int>.Ordered()
        b.insert(2)
        b.insert(4)

        let result = a.algebra.subtract(b)
        let array = toArray(result)
        #expect(array == [1, 3, 5])
    }

    @Test("Symmetric difference")
    func symmetricDifference() {
        var a = Set<Int>.Ordered()
        a.insert(1)
        a.insert(2)
        a.insert(3)
        var b = Set<Int>.Ordered()
        b.insert(2)
        b.insert(3)
        b.insert(4)

        let result = a.algebra.symmetric.difference(b)
        let array = toArray(result)
        #expect(array == [1, 4])
    }

    // MARK: - Collection Conformance

    @Test("Subscript access")
    func subscriptAccess() {
        var set = Set<String>.Ordered()
        set.insert("a")
        set.insert("b")
        set.insert("c")

        #expect(set[0] == "a")
        #expect(set[1] == "b")
        #expect(set[2] == "c")
    }

    @Test("Iteration via forEach")
    func iterationViaForEach() {
        var set = Set<Int>.Ordered()
        set.insert(10)
        set.insert(20)
        set.insert(30)

        var result: [Int] = []
        set.forEach { element in
            result.append(element)
        }

        #expect(result == [10, 20, 30])
    }

    @Test("Iteration via makeIterator")
    func iterationViaMakeIterator() {
        var set = Set<Int>.Ordered()
        set.insert(10)
        set.insert(20)
        set.insert(30)

        var iterator = set.makeIterator()
        var result: [Int] = []
        while let element = iterator.next() {
            result.append(element)
        }

        #expect(result == [10, 20, 30])
    }

    // MARK: - Properties

    @Test("Empty set")
    func emptySet() {
        let set = Set<Int>.Ordered()
        let isEmpty = set.isEmpty
        #expect(isEmpty)
    }

    @Test("Init from sequence")
    func initFromSequence() {
        let set = Set.Ordered([1, 2, 2, 3, 3, 3])
        let count = set.count
        let array = toArray(set)
        #expect(count == 3)
        #expect(array == [1, 2, 3])
    }

    @Test("Clear")
    func clear() {
        var set = Set<Int>.Ordered()
        set.insert(1)
        set.insert(2)
        set.insert(3)
        set.insert(4)
        set.insert(5)
        set.clear()

        let isEmpty = set.isEmpty
        #expect(isEmpty)
    }

    // MARK: - Equatable & Hashable (via Hash.Protocol)

    @Test("Equality")
    func equality() {
        var a = Set<Int>.Ordered()
        a.insert(1)
        a.insert(2)
        a.insert(3)
        var b = Set<Int>.Ordered()
        b.insert(1)
        b.insert(2)
        b.insert(3)
        var c = Set<Int>.Ordered()
        c.insert(3)
        c.insert(2)
        c.insert(1)

        let aEqualsB = a == b
        let aNotEqualsC = a != c
        #expect(aEqualsB)
        #expect(aNotEqualsC)  // Order matters
    }

    @Test("Hashable")
    func hashable() {
        var a = Set<Int>.Ordered()
        a.insert(1)
        a.insert(2)
        a.insert(3)
        var b = Set<Int>.Ordered()
        b.insert(1)
        b.insert(2)
        b.insert(3)

        let hashA = a.hashValue
        let hashB = b.hashValue
        #expect(hashA == hashB)
    }

    // MARK: - Error Types

    @Test("Bounds error")
    func boundsError() {
        var set = Set<Int>.Ordered()
        set.insert(1)
        set.insert(2)
        set.insert(3)

        #expect(throws: Set<Int>.Ordered.Error.self) {
            _ = try set.element(at: 10)
        }

        #expect(throws: Set<Int>.Ordered.Error.self) {
            _ = try set.element(at: -1)
        }
    }

    // MARK: - Consuming Iteration

    @Test("makeConsumingIterator yields all elements")
    func makeConsumingIteratorYieldsAllElements() {
        var set = Set<Int>.Ordered()
        set.insert(10)
        set.insert(20)
        set.insert(30)
        set.insert(40)
        set.insert(50)

        var iterator = set.makeConsumingIterator()
        var result: [Int] = []

        while let element = iterator.next() {
            result.append(element)
        }

        #expect(result == [10, 20, 30, 40, 50])
    }

    @Test("consumingForEach processes all elements")
    func consumingForEachProcessesAllElements() {
        var set = Set<Int>.Ordered()
        set.insert(1)
        set.insert(2)
        set.insert(3)
        set.insert(4)
        set.insert(5)

        var sum = 0
        set.consumingForEach { element in
            sum += element
        }

        #expect(sum == 15)
    }

    @Test("consumingCount returns correct count and iterator")
    func consumingCountReturnsCorrectCountAndIterator() {
        var set = Set<String>.Ordered()
        set.insert("a")
        set.insert("b")
        set.insert("c")
        set.insert("d")

        var counted = set.consumingCount()
        #expect(counted.count == 4)

        var result: [String] = []
        result.reserveCapacity(counted.count)

        while let element = counted.iterator.next() {
            result.append(element)
        }

        #expect(result == ["a", "b", "c", "d"])
    }

    @Test("Consuming iterator handles empty set")
    func consumingIteratorHandlesEmptySet() {
        let set = Set<Int>.Ordered()

        var iterator = set.makeConsumingIterator()
        let next = iterator.next()
        #expect(next == nil)
    }

    @Test("Consuming iteration preserves order")
    func consumingIterationPreservesOrder() {
        var set = Set<String>.Ordered()
        set.insert("charlie")
        set.insert("alpha")
        set.insert("bravo")

        var result: [String] = []
        set.consumingForEach { element in
            result.append(element)
        }

        #expect(result == ["charlie", "alpha", "bravo"])
    }

    // MARK: - Bounded Consuming Iteration

    @Test("Bounded: makeConsumingIterator yields all elements")
    func boundedMakeConsumingIterator() throws {
        var set = try Set<Int>.Ordered.Bounded(capacity: 10)
        try set.insert(10)
        try set.insert(20)
        try set.insert(30)

        var iterator = set.makeConsumingIterator()
        var result: [Int] = []

        while let element = iterator.next() {
            result.append(element)
        }

        #expect(result == [10, 20, 30])
    }

    @Test("Bounded: consumingForEach processes all elements")
    func boundedConsumingForEach() throws {
        var set = try Set<Int>.Ordered.Bounded(capacity: 10)
        try set.insert(1)
        try set.insert(2)
        try set.insert(3)

        var sum = 0
        set.consumingForEach { element in
            sum += element
        }

        #expect(sum == 6)
    }

    @Test("Bounded: consumingCount returns correct count")
    func boundedConsumingCount() throws {
        var set = try Set<String>.Ordered.Bounded(capacity: 10)
        try set.insert("a")
        try set.insert("b")

        var counted = set.consumingCount()
        #expect(counted.count == 2)

        var result: [String] = []
        while let element = counted.iterator.next() {
            result.append(element)
        }
        #expect(result == ["a", "b"])
    }

    @Test("Bounded: consuming iterator handles empty set")
    func boundedConsumingIteratorEmpty() throws {
        let set = try Set<Int>.Ordered.Bounded(capacity: 10)
        var iterator = set.makeConsumingIterator()
        let next = iterator.next()
        #expect(next == nil)
    }

    // MARK: - Inline Consuming Iteration

    @Test("Inline: makeConsumingIterator yields all elements")
    func inlineMakeConsumingIterator() throws {
        var set = Set<Int>.Ordered.Inline<8>()
        try set.insert(10)
        try set.insert(20)
        try set.insert(30)

        var iterator = set.makeConsumingIterator()
        var result: [Int] = []

        while let element = iterator.next() {
            result.append(element)
        }

        #expect(result == [10, 20, 30])
    }

    @Test("Inline: consumingForEach processes all elements")
    func inlineConsumingForEach() throws {
        var set = Set<Int>.Ordered.Inline<8>()
        try set.insert(1)
        try set.insert(2)
        try set.insert(3)

        var sum = 0
        set.consumingForEach { element in
            sum += element
        }

        #expect(sum == 6)
    }

    @Test("Inline: consumingCount returns correct count")
    func inlineConsumingCount() throws {
        var set = Set<String>.Ordered.Inline<8>()
        try set.insert("a")
        try set.insert("b")

        var counted = set.consumingCount()
        #expect(counted.count == 2)

        var result: [String] = []
        while let element = counted.iterator.next() {
            result.append(element)
        }
        #expect(result == ["a", "b"])
    }

    @Test("Inline: consuming iterator handles empty set")
    func inlineConsumingIteratorEmpty() {
        let set = Set<Int>.Ordered.Inline<8>()
        var iterator = set.makeConsumingIterator()
        let next = iterator.next()
        #expect(next == nil)
    }

    @Test("Inline: consuming full capacity set")
    func inlineConsumingFullCapacity() throws {
        var set = Set<Int>.Ordered.Inline<4>()
        try set.insert(1)
        try set.insert(2)
        try set.insert(3)
        try set.insert(4)
        precondition(set.isFull, "Should be at full capacity")

        var result: [Int] = []
        set.consumingForEach { element in
            result.append(element)
        }

        #expect(result == [1, 2, 3, 4])
    }

    // MARK: - Small Consuming Iteration

    @Test("Small: makeConsumingIterator yields all elements (inline mode)")
    func smallMakeConsumingIteratorInline() {
        var set = Set<Int>.Ordered.Small<4>()
        set.insert(10)
        set.insert(20)
        set.insert(30)
        precondition(!set.isSpilled, "Should be in inline mode")

        var iterator = set.makeConsumingIterator()
        var result: [Int] = []

        while let element = iterator.next() {
            result.append(element)
        }

        #expect(result == [10, 20, 30])
    }

    @Test("Small: makeConsumingIterator yields all elements (heap mode)")
    func smallMakeConsumingIteratorHeap() {
        var set = Set<Int>.Ordered.Small<2>()
        set.insert(1)
        set.insert(2)
        set.insert(3) // Triggers spill
        set.insert(4)
        precondition(set.isSpilled, "Should be in heap mode")

        var iterator = set.makeConsumingIterator()
        var result: [Int] = []

        while let element = iterator.next() {
            result.append(element)
        }

        #expect(result == [1, 2, 3, 4])
    }

    @Test("Small: consumingForEach processes all elements")
    func smallConsumingForEach() {
        var set = Set<Int>.Ordered.Small<4>()
        set.insert(1)
        set.insert(2)
        set.insert(3)

        var sum = 0
        set.consumingForEach { element in
            sum += element
        }

        #expect(sum == 6)
    }

    @Test("Small: consumingCount returns correct count")
    func smallConsumingCount() {
        var set = Set<String>.Ordered.Small<4>()
        set.insert("a")
        set.insert("b")

        var counted = set.consumingCount()
        #expect(counted.count == 2)

        var result: [String] = []
        while let element = counted.iterator.next() {
            result.append(element)
        }
        #expect(result == ["a", "b"])
    }

    @Test("Small: consuming iterator handles empty set")
    func smallConsumingIteratorEmpty() {
        let set = Set<Int>.Ordered.Small<4>()
        var iterator = set.makeConsumingIterator()
        let next = iterator.next()
        #expect(next == nil)
    }

    @Test("Small: consuming after spill to heap")
    func smallConsumingAfterSpill() {
        var set = Set<Int>.Ordered.Small<2>()
        set.insert(1)
        set.insert(2)
        precondition(!set.isSpilled, "Should start in inline mode")

        set.insert(3)
        set.insert(4)
        set.insert(5)
        precondition(set.isSpilled, "Should be in heap mode after spill")

        var result: [Int] = []
        set.consumingForEach { element in
            result.append(element)
        }

        #expect(result == [1, 2, 3, 4, 5])
    }

    // MARK: - Partial Consumption Tests (Double-Free Prevention)

    @Test("Ordered: partial consumption cleans up remaining")
    func orderedPartialConsumption() {
        var set = Set<Int>.Ordered()
        set.insert(1)
        set.insert(2)
        set.insert(3)
        set.insert(4)
        set.insert(5)
        var iterator = set.makeConsumingIterator()

        // Only consume first 2
        _ = iterator.next()
        _ = iterator.next()

        // Iterator goes out of scope - deinit should clean up remaining 3 elements
        // If double-free occurred, this would crash
    }

    @Test("Bounded: partial consumption cleans up remaining")
    func boundedPartialConsumption() throws {
        var set = try Set<Int>.Ordered.Bounded(capacity: 10)
        try set.insert(1)
        try set.insert(2)
        try set.insert(3)
        try set.insert(4)
        try set.insert(5)

        var iterator = set.makeConsumingIterator()

        // Only consume first 2
        _ = iterator.next()
        _ = iterator.next()

        // Iterator goes out of scope - deinit should clean up remaining 3 elements
    }

    @Test("Inline: partial consumption cleans up remaining")
    func inlinePartialConsumption() throws {
        var set = Set<Int>.Ordered.Inline<8>()
        try set.insert(1)
        try set.insert(2)
        try set.insert(3)
        try set.insert(4)
        try set.insert(5)

        var iterator = set.makeConsumingIterator()

        // Only consume first 2
        _ = iterator.next()
        _ = iterator.next()

        // Iterator goes out of scope - deinit should clean up remaining 3 elements
    }

    @Test("Small: partial consumption cleans up remaining (inline mode)")
    func smallPartialConsumptionInline() {
        var set = Set<Int>.Ordered.Small<8>()
        set.insert(1)
        set.insert(2)
        set.insert(3)
        set.insert(4)
        set.insert(5)
        precondition(!set.isSpilled, "Should be in inline mode")

        var iterator = set.makeConsumingIterator()

        // Only consume first 2
        _ = iterator.next()
        _ = iterator.next()

        // Iterator goes out of scope - deinit should clean up remaining 3 elements
    }

    @Test("Small: partial consumption cleans up remaining (heap mode)")
    func smallPartialConsumptionHeap() {
        var set = Set<Int>.Ordered.Small<2>()
        set.insert(1)
        set.insert(2)
        set.insert(3)
        set.insert(4)
        set.insert(5)
        precondition(set.isSpilled, "Should be in heap mode")

        var iterator = set.makeConsumingIterator()

        // Only consume first 2
        _ = iterator.next()
        _ = iterator.next()

        // Iterator goes out of scope - deinit should clean up remaining 3 elements
    }
}
