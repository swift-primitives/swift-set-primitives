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

// MARK: - Test Suite Structure

@Suite("Set.Ordered.Builder")
struct SetOrderedBuilderTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite struct StaticMethods {}
}

// MARK: - Helpers

extension SetOrderedBuilderTests {
    fileprivate static func collected<E: Hash.`Protocol` & Copyable>(
        _ set: borrowing Set<E>.Ordered
    ) -> [E] {
        var result: [E] = []
        try! set.forEach { result.append($0) }
        return result
    }
}

// MARK: - Unit Tests

extension SetOrderedBuilderTests.Unit {

    @Test
    func `Single element expression`() {
        let set = Set<Int>.Ordered { 42 }
        #expect(SetOrderedBuilderTests.collected(set) == [42])
    }

    @Test
    func `Multiple elements preserve insertion order`() {
        let set = Set<Int>.Ordered {
            3
            1
            2
        }
        #expect(SetOrderedBuilderTests.collected(set) == [3, 1, 2])
    }

    @Test
    func `Duplicates after first are ignored`() {
        let set = Set<Int>.Ordered {
            1
            2
            1
            3
            2
        }
        #expect(SetOrderedBuilderTests.collected(set) == [1, 2, 3])
    }

    @Test
    func `Optional element - some`() {
        let value: Int? = 42
        let set = Set<Int>.Ordered { value }
        #expect(SetOrderedBuilderTests.collected(set) == [42])
    }

    @Test
    func `Optional element - none`() {
        let value: Int? = nil
        let set = Set<Int>.Ordered { value }
        #expect(set.isEmpty)
    }

    @Test
    func `Mixed elements and optionals`() {
        let some: Int? = 2
        let none: Int? = nil
        let set = Set<Int>.Ordered {
            1
            some
            none
            3
        }
        #expect(SetOrderedBuilderTests.collected(set) == [1, 2, 3])
    }

    @Test
    func `Empty block`() {
        let set = Set<Int>.Ordered {}
        #expect(set.isEmpty)
    }

    @Test
    func `String elements`() {
        let set = Set<String>.Ordered {
            "alpha"
            "beta"
            "gamma"
        }
        #expect(SetOrderedBuilderTests.collected(set) == ["alpha", "beta", "gamma"])
    }
}

// MARK: - Control Flow

extension SetOrderedBuilderTests.Unit {

    @Test
    func `Conditional include`() {
        let include = true
        let set = Set<Int>.Ordered {
            1
            if include {
                2
            }
            3
        }
        #expect(SetOrderedBuilderTests.collected(set) == [1, 2, 3])
    }

    @Test
    func `Conditional exclude`() {
        let include = false
        let set = Set<Int>.Ordered {
            1
            if include {
                2
            }
            3
        }
        #expect(SetOrderedBuilderTests.collected(set) == [1, 3])
    }

    @Test
    func `If-else first branch`() {
        let condition = true
        let set = Set<Int>.Ordered {
            if condition {
                10
            } else {
                20
            }
        }
        #expect(SetOrderedBuilderTests.collected(set) == [10])
    }

    @Test
    func `For loop produces ordered set`() {
        let set = Set<Int>.Ordered {
            for i in 1...5 {
                i
            }
        }
        #expect(SetOrderedBuilderTests.collected(set) == [1, 2, 3, 4, 5])
    }
}

// MARK: - Edge Cases

extension SetOrderedBuilderTests.EdgeCase {

    @Test
    func `Many duplicates collapse`() {
        let set = Set<Int>.Ordered {
            1
            1
            1
            1
            1
        }
        #expect(SetOrderedBuilderTests.collected(set) == [1])
    }

    @Test
    func `All unique many elements`() {
        let set = Set<Int>.Ordered {
            for i in 1...10 {
                i
            }
        }
        #expect(SetOrderedBuilderTests.collected(set) == Swift.Array(1...10))
    }

    @Test
    func `Deeply nested conditionals`() {
        let a = true
        let b = false
        let c = true
        let set = Set<Int>.Ordered {
            0
            if a {
                1
                if b {
                    2
                } else {
                    3
                    if c {
                        4
                    }
                }
            }
            99
        }
        #expect(SetOrderedBuilderTests.collected(set) == [0, 1, 3, 4, 99])
    }
}

// MARK: - Integration

extension SetOrderedBuilderTests.Integration {

    @Test
    func `Builder result accepts further inserts`() {
        var set = Set<Int>.Ordered {
            1
            2
        }
        let (inserted3, _) = set.insert(3)
        let (inserted1, _) = set.insert(1)  // duplicate
        #expect(inserted3)
        #expect(!inserted1)
        #expect(SetOrderedBuilderTests.collected(set) == [1, 2, 3])
    }
}

// MARK: - Static Method Tests

extension SetOrderedBuilderTests.StaticMethods {

    @Test
    func `buildExpression single element`() {
        let result = Set<Int>.Ordered.Builder.buildExpression(42)
        #expect(result == [42])
    }

    @Test
    func `buildExpression array`() {
        let result = Set<Int>.Ordered.Builder.buildExpression([1, 2, 3])
        #expect(result == [1, 2, 3])
    }

    @Test
    func `buildPartialBlock accumulated and next`() {
        let result = Set<Int>.Ordered.Builder.buildPartialBlock(
            accumulated: [1, 2],
            next: [3, 4]
        )
        #expect(result == [1, 2, 3, 4])
    }

    @Test
    func `buildArray flattens components`() {
        let result = Set<Int>.Ordered.Builder.buildArray([[1, 2], [3, 4], [5]])
        #expect(result == [1, 2, 3, 4, 5])
    }
}
