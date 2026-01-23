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

    // MARK: - Consuming Iteration (via .consume().forEach pattern)

    @Test("consume().forEach yields all elements")
    func consumeForEachYieldsAllElements() {
        var set = Set<Int>.Ordered()
        set.insert(10)
        set.insert(20)
        set.insert(30)
        set.insert(40)
        set.insert(50)

        var result: [Int] = []
        set.consume().forEach { element in
            result.append(element)
        }

        #expect(result == [10, 20, 30, 40, 50])
    }

    @Test("consume().forEach processes all elements")
    func consumeForEachProcessesAllElements() {
        var set = Set<Int>.Ordered()
        set.insert(1)
        set.insert(2)
        set.insert(3)
        set.insert(4)
        set.insert(5)

        var sum = 0
        set.consume().forEach { element in
            sum += element
        }

        #expect(sum == 15)
    }

    @Test("consume() with manual iteration")
    func consumeWithManualIteration() {
        var set = Set<String>.Ordered()
        set.insert("a")
        set.insert("b")
        set.insert("c")
        set.insert("d")

        let count = set.count
        #expect(count == 4)

        var view = set.consume()
        var result: [String] = []
        result.reserveCapacity(count)

        while let element = view.next() {
            result.append(element)
        }

        #expect(result == ["a", "b", "c", "d"])
    }

    @Test("consume() handles empty set")
    func consumeHandlesEmptySet() {
        let set = Set<Int>.Ordered()

        var view = set.consume()
        let next = view.next()
        #expect(next == nil)
    }

    @Test("consume().forEach preserves order")
    func consumeForEachPreservesOrder() {
        var set = Set<String>.Ordered()
        set.insert("charlie")
        set.insert("alpha")
        set.insert("bravo")

        var result: [String] = []
        set.consume().forEach { element in
            result.append(element)
        }

        #expect(result == ["charlie", "alpha", "bravo"])
    }

    // MARK: - Bounded Consuming Iteration

    @Test("Bounded: consume().forEach yields all elements")
    func boundedConsumeForEach() throws {
        var set = try Set<Int>.Ordered.Bounded(capacity: 10)
        try set.insert(10)
        try set.insert(20)
        try set.insert(30)

        var result: [Int] = []
        set.consume().forEach { element in
            result.append(element)
        }

        #expect(result == [10, 20, 30])
    }

    @Test("Bounded: consume().forEach processes all elements")
    func boundedConsumeForEachProcesses() throws {
        var set = try Set<Int>.Ordered.Bounded(capacity: 10)
        try set.insert(1)
        try set.insert(2)
        try set.insert(3)

        var sum = 0
        set.consume().forEach { element in
            sum += element
        }

        #expect(sum == 6)
    }

    @Test("Bounded: consume() with manual iteration")
    func boundedConsumeManualIteration() throws {
        var set = try Set<String>.Ordered.Bounded(capacity: 10)
        try set.insert("a")
        try set.insert("b")

        let count = set.count
        #expect(count == 2)

        var view = set.consume()
        var result: [String] = []
        while let element = view.next() {
            result.append(element)
        }
        #expect(result == ["a", "b"])
    }

    @Test("Bounded: consume() handles empty set")
    func boundedConsumeEmpty() throws {
        let set = try Set<Int>.Ordered.Bounded(capacity: 10)
        var view = set.consume()
        let next = view.next()
        #expect(next == nil)
    }

    // MARK: - Inline Consuming Iteration

    @Test("Inline: consume().forEach yields all elements")
    func inlineConsumeForEach() throws {
        var set = Set<Int>.Ordered.Inline<8>()
        try set.insert(10)
        try set.insert(20)
        try set.insert(30)

        var result: [Int] = []
        set.consume().forEach { element in
            result.append(element)
        }

        #expect(result == [10, 20, 30])
    }

    @Test("Inline: consume().forEach processes all elements")
    func inlineConsumeForEachProcesses() throws {
        var set = Set<Int>.Ordered.Inline<8>()
        try set.insert(1)
        try set.insert(2)
        try set.insert(3)

        var sum = 0
        set.consume().forEach { element in
            sum += element
        }

        #expect(sum == 6)
    }

    @Test("Inline: consume() with manual iteration")
    func inlineConsumeManualIteration() throws {
        var set = Set<String>.Ordered.Inline<8>()
        try set.insert("a")
        try set.insert("b")

        let count = set.count
        #expect(count == 2)

        var view = set.consume()
        var result: [String] = []
        while let element = view.next() {
            result.append(element)
        }
        #expect(result == ["a", "b"])
    }

    @Test("Inline: consume() handles empty set")
    func inlineConsumeEmpty() {
        let set = Set<Int>.Ordered.Inline<8>()
        var view = set.consume()
        let next = view.next()
        #expect(next == nil)
    }

    @Test("Inline: consume() full capacity set")
    func inlineConsumeFullCapacity() throws {
        var set = Set<Int>.Ordered.Inline<4>()
        try set.insert(1)
        try set.insert(2)
        try set.insert(3)
        try set.insert(4)
        precondition(set.isFull, "Should be at full capacity")

        var result: [Int] = []
        set.consume().forEach { element in
            result.append(element)
        }

        #expect(result == [1, 2, 3, 4])
    }

    // MARK: - Small Consuming Iteration

    @Test("Small: consume().forEach yields all elements (inline mode)")
    func smallConsumeForEachInline() {
        var set = Set<Int>.Ordered.Small<4>()
        set.insert(10)
        set.insert(20)
        set.insert(30)
        precondition(!set.isSpilled, "Should be in inline mode")

        var result: [Int] = []
        set.consume().forEach { element in
            result.append(element)
        }

        #expect(result == [10, 20, 30])
    }

    @Test("Small: consume().forEach yields all elements (heap mode)")
    func smallConsumeForEachHeap() {
        var set = Set<Int>.Ordered.Small<2>()
        set.insert(1)
        set.insert(2)
        set.insert(3) // Triggers spill
        set.insert(4)
        precondition(set.isSpilled, "Should be in heap mode")

        var result: [Int] = []
        set.consume().forEach { element in
            result.append(element)
        }

        #expect(result == [1, 2, 3, 4])
    }

    @Test("Small: consume().forEach processes all elements")
    func smallConsumeForEachProcesses() {
        var set = Set<Int>.Ordered.Small<4>()
        set.insert(1)
        set.insert(2)
        set.insert(3)

        var sum = 0
        set.consume().forEach { element in
            sum += element
        }

        #expect(sum == 6)
    }

    @Test("Small: consume() with manual iteration")
    func smallConsumeManualIteration() {
        var set = Set<String>.Ordered.Small<4>()
        set.insert("a")
        set.insert("b")

        let count = set.count
        #expect(count == 2)

        var view = set.consume()
        var result: [String] = []
        while let element = view.next() {
            result.append(element)
        }
        #expect(result == ["a", "b"])
    }

    @Test("Small: consume() handles empty set")
    func smallConsumeEmpty() {
        let set = Set<Int>.Ordered.Small<4>()
        var view = set.consume()
        let next = view.next()
        #expect(next == nil)
    }

    @Test("Small: consume() after spill to heap")
    func smallConsumeAfterSpill() {
        var set = Set<Int>.Ordered.Small<2>()
        set.insert(1)
        set.insert(2)
        precondition(!set.isSpilled, "Should start in inline mode")

        set.insert(3)
        set.insert(4)
        set.insert(5)
        precondition(set.isSpilled, "Should be in heap mode after spill")

        var result: [Int] = []
        set.consume().forEach { element in
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
        var view = set.consume()

        // Only consume first 2
        _ = view.next()
        _ = view.next()

        // View goes out of scope - State's deinit should clean up remaining 3 elements
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

        var view = set.consume()

        // Only consume first 2
        _ = view.next()
        _ = view.next()

        // View goes out of scope - State's deinit should clean up remaining 3 elements
    }

    @Test("Inline: partial consumption cleans up remaining")
    func inlinePartialConsumption() throws {
        var set = Set<Int>.Ordered.Inline<8>()
        try set.insert(1)
        try set.insert(2)
        try set.insert(3)
        try set.insert(4)
        try set.insert(5)

        var view = set.consume()

        // Only consume first 2
        _ = view.next()
        _ = view.next()

        // View goes out of scope - State's deinit should clean up remaining 3 elements
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

        var view = set.consume()

        // Only consume first 2
        _ = view.next()
        _ = view.next()

        // View goes out of scope - State's deinit should clean up remaining 3 elements
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

        var view = set.consume()

        // Only consume first 2
        _ = view.next()
        _ = view.next()

        // View goes out of scope - State's deinit should clean up remaining 3 elements
    }
}
