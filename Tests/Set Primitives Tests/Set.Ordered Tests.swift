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
import Set_Primitives_Test_Support

// MARK: - Helper to convert Set.Ordered to Array

// Note: Set.Ordered is ~Copyable and cannot conform to Swift.Sequence.
// This helper uses index-based iteration to extract elements.
func toArray<Element: Hashable>(_ set: borrowing Set<Element>.Ordered) -> [Element] {
    var result: [Element] = []
    for i in Index<Element>.zero..<set.count {
        result.append(set[i])
    }
    return result
}

@Suite("Set.Ordered")
struct OrderedSetTests {

    // MARK: - Basic Operations

    @Test
    func `Insert and contains`() {
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

    @Test
    func `Index lookup`() {
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

    @Test
    func `Remove element`() {
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

    @Test
    func `Insertion order preserved`() {
        var set = Set<String>.Ordered()
        set.insert("charlie")
        set.insert("alpha")
        set.insert("bravo")

        let array = toArray(set)
        #expect(array == ["charlie", "alpha", "bravo"])
    }

    @Test
    func `Order after removal`() {
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

    @Test
    func `Re-insertion goes to end`() {
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

    @Test
    func `Union`() {
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

    @Test
    func `Intersection`() {
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

    @Test
    func `Subtract`() {
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

    @Test
    func `Symmetric difference`() {
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

    @Test
    func `Subscript access`() {
        var set = Set<String>.Ordered()
        set.insert("a")
        set.insert("b")
        set.insert("c")

        #expect(set[0] == "a")
        #expect(set[1] == "b")
        #expect(set[2] == "c")
    }

    @Test
    func `Iteration via forEach`() {
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

    @Test
    func `Iteration via makeIterator`() {
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

    @Test
    func `Empty set`() {
        let set = Set<Int>.Ordered()
        let isEmpty = set.isEmpty
        #expect(isEmpty)
    }

    @Test
    func `Init from sequence`() {
        let set = Set.Ordered([1, 2, 2, 3, 3, 3])
        let count = set.count
        let array = toArray(set)
        #expect(count == 3)
        #expect(array == [1, 2, 3])
    }

    @Test
    func `Clear`() {
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

    @Test
    func `Equality`() {
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

    @Test
    func `Hashable`() {
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

    @Test
    func `Bounds error for out-of-range index`() {
        var set = Set<Int>.Ordered()
        set.insert(1)
        set.insert(2)
        set.insert(3)

        #expect(throws: Set<Int>.Ordered.Error.self) {
            _ = try set.element(at: 10)
        }

        // Note: Negative indices cannot be tested directly since Index<Element>
        // wraps Ordinal (UInt) and cannot represent negative values.
        // The type system prevents negative index access at compile time.
    }

    // MARK: - Consuming Iteration (via .consume().forEach pattern)

    @Test
    func `consume().forEach yields all elements`() {
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

    @Test
    func `consume().forEach processes all elements`() {
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

    @Test
    func `consume() with manual iteration`() {
        var set = Set<String>.Ordered()
        set.insert("a")
        set.insert("b")
        set.insert("c")
        set.insert("d")

        let count = set.count
        #expect(count == 4)

        var view = set.consume()
        var result: [String] = []
        result.reserveCapacity(Int(bitPattern: count))

        while let element = view.next() {
            result.append(element)
        }

        #expect(result == ["a", "b", "c", "d"])
    }

    @Test
    func `consume() handles empty set`() {
        let set = Set<Int>.Ordered()

        var view = set.consume()
        let next = view.next()
        #expect(next == nil)
    }

    @Test
    func `consume().forEach preserves order`() {
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

    @Test
    func `Bounded: consume().forEach yields all elements`() throws {
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

    @Test
    func `Bounded: consume().forEach processes all elements`() throws {
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

    @Test
    func `Bounded: consume() with manual iteration`() throws {
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

    @Test
    func `Bounded: consume() handles empty set`() throws {
        let set = try Set<Int>.Ordered.Bounded(capacity: 10)
        var view = set.consume()
        let next = view.next()
        #expect(next == nil)
    }

    // MARK: - Inline Consuming Iteration

    @Test
    func `Inline: consume().forEach yields all elements`() throws {
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

    @Test
    func `Inline: consume().forEach processes all elements`() throws {
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

    @Test
    func `Inline: consume() with manual iteration`() throws {
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

    @Test
    func `Inline: consume() handles empty set`() {
        let set = Set<Int>.Ordered.Inline<8>()
        var view = set.consume()
        let next = view.next()
        #expect(next == nil)
    }

    @Test
    func `Inline: consume() full capacity set`() throws {
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

    @Test
    func `Small: consume().forEach yields all elements (inline mode)`() {
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

    @Test
    func `Small: consume().forEach yields all elements (heap mode)`() {
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

    @Test
    func `Small: consume().forEach processes all elements`() {
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

    @Test
    func `Small: consume() with manual iteration`() {
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

    @Test
    func `Small: consume() handles empty set`() {
        let set = Set<Int>.Ordered.Small<4>()
        var view = set.consume()
        let next = view.next()
        #expect(next == nil)
    }

    @Test
    func `Small: consume() after spill to heap`() {
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

    @Test
    func `Ordered: partial consumption cleans up remaining`() {
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

    @Test
    func `Bounded: partial consumption cleans up remaining`() throws {
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

    @Test
    func `Inline: partial consumption cleans up remaining`() throws {
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

    @Test
    func `Small: partial consumption cleans up remaining (inline mode)`() {
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

    @Test
    func `Small: partial consumption cleans up remaining (heap mode)`() {
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
