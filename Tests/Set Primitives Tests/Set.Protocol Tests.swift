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

// Note: #expect macro cannot handle ~Copyable types (Static, Small) in
// property access or function call decomposition. All Bool results from
// operations involving ~Copyable receivers or arguments are extracted
// to local `let` bindings before passing to #expect.

@Suite("Set.Protocol")
struct SetProtocolTests {

    // MARK: - isEmpty

    @Test
    func `isEmpty on empty sets`() throws {
        let ordered = Set<Int>.Ordered()
        #expect(ordered.isEmpty)

        let fixed = try Set<Int>.Ordered.Fixed(capacity: 4)
        #expect(fixed.isEmpty)

        do {
            let _static = Set<Int>.Ordered.Static<4>()
            let empty = _static.isEmpty
            #expect(empty)
        }

        do {
            let small = Set<Int>.Ordered.Small<4>()
            let empty = small.isEmpty
            #expect(empty)
        }
    }

    @Test
    func `isEmpty on non-empty sets`() throws {
        var ordered = Set<Int>.Ordered()
        ordered.insert(1)
        #expect(!ordered.isEmpty)

        var fixed = try Set<Int>.Ordered.Fixed(capacity: 4)
        try fixed.insert(1)
        #expect(!fixed.isEmpty)

        do {
            var _static = Set<Int>.Ordered.Static<4>()
            try _static.insert(1)
            let empty = _static.isEmpty
            #expect(!empty)
        }

        do {
            var small = Set<Int>.Ordered.Small<4>()
            small.insert(1)
            let empty = small.isEmpty
            #expect(!empty)
        }
    }

    // MARK: - isDisjoint

    @Test
    func `Disjoint sets`() {
        var a = Set<Int>.Ordered()
        a.insert(1); a.insert(2)
        var b = Set<Int>.Ordered()
        b.insert(3); b.insert(4)
        #expect(a.isDisjoint(with: b))
    }

    @Test
    func `Overlapping sets are not disjoint`() {
        var a = Set<Int>.Ordered()
        a.insert(1); a.insert(2); a.insert(3)
        var b = Set<Int>.Ordered()
        b.insert(2); b.insert(4)
        #expect(!a.isDisjoint(with: b))
    }

    @Test
    func `Empty set is disjoint with any set`() {
        let empty = Set<Int>.Ordered()
        var nonEmpty = Set<Int>.Ordered()
        nonEmpty.insert(1)
        #expect(empty.isDisjoint(with: nonEmpty))
        #expect(nonEmpty.isDisjoint(with: empty))
        #expect(empty.isDisjoint(with: empty))
    }

    // MARK: - isSubset

    @Test
    func `Subset`() {
        var small = Set<Int>.Ordered()
        small.insert(1); small.insert(2)
        var large = Set<Int>.Ordered()
        large.insert(1); large.insert(2); large.insert(3)
        #expect(small.isSubset(of: large))
        #expect(!large.isSubset(of: small))
    }

    @Test
    func `Equal sets are subsets of each other`() {
        var a = Set<Int>.Ordered()
        a.insert(1); a.insert(2)
        var b = Set<Int>.Ordered()
        b.insert(1); b.insert(2)
        #expect(a.isSubset(of: b))
        #expect(b.isSubset(of: a))
    }

    @Test
    func `Empty set is subset of any set`() {
        let empty = Set<Int>.Ordered()
        var nonEmpty = Set<Int>.Ordered()
        nonEmpty.insert(1)
        #expect(empty.isSubset(of: nonEmpty))
        #expect(empty.isSubset(of: empty))
    }

    // MARK: - isSuperset

    @Test
    func `Superset`() {
        var large = Set<Int>.Ordered()
        large.insert(1); large.insert(2); large.insert(3)
        var small = Set<Int>.Ordered()
        small.insert(1); small.insert(2)
        #expect(large.isSuperset(of: small))
        #expect(!small.isSuperset(of: large))
    }

    @Test
    func `Any set is superset of empty set`() {
        let empty = Set<Int>.Ordered()
        var nonEmpty = Set<Int>.Ordered()
        nonEmpty.insert(1)
        #expect(nonEmpty.isSuperset(of: empty))
        #expect(empty.isSuperset(of: empty))
    }

    // MARK: - isStrictSubset

    @Test
    func `Strict subset`() {
        var small = Set<Int>.Ordered()
        small.insert(1); small.insert(2)
        var large = Set<Int>.Ordered()
        large.insert(1); large.insert(2); large.insert(3)
        #expect(small.isStrictSubset(of: large))
        #expect(!large.isStrictSubset(of: small))
    }

    @Test
    func `Equal sets are not strict subsets`() {
        var a = Set<Int>.Ordered()
        a.insert(1); a.insert(2)
        var b = Set<Int>.Ordered()
        b.insert(1); b.insert(2)
        #expect(!a.isStrictSubset(of: b))
    }

    @Test
    func `Empty set is strict subset of non-empty set`() {
        let empty = Set<Int>.Ordered()
        var nonEmpty = Set<Int>.Ordered()
        nonEmpty.insert(1)
        #expect(empty.isStrictSubset(of: nonEmpty))
        #expect(!empty.isStrictSubset(of: empty))
    }

    // MARK: - isStrictSuperset

    @Test
    func `Strict superset`() {
        var large = Set<Int>.Ordered()
        large.insert(1); large.insert(2); large.insert(3)
        var small = Set<Int>.Ordered()
        small.insert(1); small.insert(2)
        #expect(large.isStrictSuperset(of: small))
        #expect(!small.isStrictSuperset(of: large))
    }

    @Test
    func `Equal sets are not strict supersets`() {
        var a = Set<Int>.Ordered()
        a.insert(1); a.insert(2)
        var b = Set<Int>.Ordered()
        b.insert(1); b.insert(2)
        #expect(!a.isStrictSuperset(of: b))
    }

    // MARK: - Protocol Algebra

    @Test
    func `Union via protocol default`() {
        var a = Set<Int>.Ordered()
        a.insert(1); a.insert(2); a.insert(3)
        var b = Set<Int>.Ordered()
        b.insert(3); b.insert(4); b.insert(5)
        let result = a.union(b)
        #expect(toArray(result) == [1, 2, 3, 4, 5])
    }

    @Test
    func `Intersection via protocol default`() {
        var a = Set<Int>.Ordered()
        a.insert(1); a.insert(2); a.insert(3); a.insert(4)
        var b = Set<Int>.Ordered()
        b.insert(2); b.insert(4); b.insert(6)
        let result = a.intersection(b)
        #expect(toArray(result) == [2, 4])
    }

    @Test
    func `Subtract via protocol default`() {
        var a = Set<Int>.Ordered()
        a.insert(1); a.insert(2); a.insert(3); a.insert(4); a.insert(5)
        var b = Set<Int>.Ordered()
        b.insert(2); b.insert(4)
        let result = a.subtract(b)
        #expect(toArray(result) == [1, 3, 5])
    }

    @Test
    func `Symmetric difference via protocol default`() {
        var a = Set<Int>.Ordered()
        a.insert(1); a.insert(2); a.insert(3)
        var b = Set<Int>.Ordered()
        b.insert(2); b.insert(3); b.insert(4)
        let result = a.symmetricDifference(b)
        #expect(toArray(result) == [1, 4])
    }

    @Test
    func `Algebra with empty sets`() {
        let empty = Set<Int>.Ordered()
        var nonEmpty = Set<Int>.Ordered()
        nonEmpty.insert(1); nonEmpty.insert(2)

        #expect(toArray(empty.union(nonEmpty)) == [1, 2])
        #expect(toArray(nonEmpty.union(empty)) == [1, 2])
        #expect(toArray(empty.intersection(nonEmpty)) == [])
        #expect(toArray(nonEmpty.intersection(empty)) == [])
        #expect(toArray(nonEmpty.subtract(empty)) == [1, 2])
        #expect(toArray(empty.subtract(nonEmpty)) == [])
        #expect(toArray(empty.symmetricDifference(nonEmpty)) == [1, 2])
    }

    // MARK: - Heterogeneous Variant Pairs

    @Test
    func `Ordered isDisjoint with Fixed`() throws {
        var ordered = Set<Int>.Ordered()
        ordered.insert(1); ordered.insert(2)
        var fixed = try Set<Int>.Ordered.Fixed(capacity: 4)
        try fixed.insert(3); try fixed.insert(4)
        #expect(ordered.isDisjoint(with: fixed))

        try fixed.insert(2)
        #expect(!ordered.isDisjoint(with: fixed))
    }

    @Test
    func `Ordered isSubset of Static`() throws {
        var ordered = Set<Int>.Ordered()
        ordered.insert(1); ordered.insert(2)
        var _static = Set<Int>.Ordered.Static<8>()
        try _static.insert(1); try _static.insert(2); try _static.insert(3)

        let isSubset = ordered.isSubset(of: _static)
        #expect(isSubset)
        let isSuperset = _static.isSuperset(of: ordered)
        #expect(isSuperset)
        let isStrictSubset = ordered.isStrictSubset(of: _static)
        #expect(isStrictSubset)
    }

    @Test
    func `Fixed union with Small`() throws {
        var fixed = try Set<Int>.Ordered.Fixed(capacity: 4)
        try fixed.insert(1); try fixed.insert(2)
        var small = Set<Int>.Ordered.Small<4>()
        small.insert(3); small.insert(4)
        let result = fixed.union(small)
        #expect(toArray(result) == [1, 2, 3, 4])
    }

    @Test
    func `Static intersection with Ordered`() throws {
        var _static = Set<Int>.Ordered.Static<8>()
        try _static.insert(1); try _static.insert(2); try _static.insert(3)
        var ordered = Set<Int>.Ordered()
        ordered.insert(2); ordered.insert(3); ordered.insert(4)
        let result = _static.intersection(ordered)
        #expect(toArray(result) == [2, 3])
    }

    @Test
    func `Small subtract from Ordered`() {
        var small = Set<Int>.Ordered.Small<8>()
        small.insert(1); small.insert(2); small.insert(3); small.insert(4)
        var ordered = Set<Int>.Ordered()
        ordered.insert(2); ordered.insert(4)
        let result = small.subtract(ordered)
        #expect(toArray(result) == [1, 3])
    }

    @Test
    func `Small isStrictSuperset of Fixed`() throws {
        var small = Set<Int>.Ordered.Small<8>()
        small.insert(1); small.insert(2); small.insert(3)
        var fixed = try Set<Int>.Ordered.Fixed(capacity: 4)
        try fixed.insert(1); try fixed.insert(2)

        let smallIsStrict = small.isStrictSuperset(of: fixed)
        #expect(smallIsStrict)
        let fixedIsStrict = fixed.isStrictSuperset(of: small)
        #expect(!fixedIsStrict)
    }

    // MARK: - Variant-Specific Defaults

    @Test
    func `Fixed relational defaults`() throws {
        var a = try Set<Int>.Ordered.Fixed(capacity: 8)
        try a.insert(1); try a.insert(2)
        var b = try Set<Int>.Ordered.Fixed(capacity: 8)
        try b.insert(1); try b.insert(2); try b.insert(3)

        #expect(a.isSubset(of: b))
        #expect(a.isStrictSubset(of: b))
        #expect(b.isSuperset(of: a))
        #expect(b.isStrictSuperset(of: a))
        #expect(!a.isDisjoint(with: b))
    }

    @Test
    func `Static relational defaults`() throws {
        var a = Set<Int>.Ordered.Static<8>()
        try a.insert(1); try a.insert(2)
        var b = Set<Int>.Ordered.Static<8>()
        try b.insert(3); try b.insert(4)

        let disjoint = a.isDisjoint(with: b)
        #expect(disjoint)
        let subset = a.isSubset(of: b)
        #expect(!subset)
        let superset = a.isSuperset(of: b)
        #expect(!superset)
    }

    @Test
    func `Small relational defaults`() {
        var a = Set<Int>.Ordered.Small<8>()
        a.insert(1); a.insert(2); a.insert(3)
        var b = Set<Int>.Ordered.Small<8>()
        b.insert(1); b.insert(2)

        let bSubsetA = b.isSubset(of: a)
        #expect(bSubsetA)
        let bStrictSubsetA = b.isStrictSubset(of: a)
        #expect(bStrictSubsetA)
        let aSupersetB = a.isSuperset(of: b)
        #expect(aSupersetB)
        let aStrictSupersetB = a.isStrictSuperset(of: b)
        #expect(aStrictSupersetB)
        let disjoint = a.isDisjoint(with: b)
        #expect(!disjoint)
    }

    @Test
    func `Fixed algebra defaults`() throws {
        var a = try Set<Int>.Ordered.Fixed(capacity: 8)
        try a.insert(1); try a.insert(2); try a.insert(3)
        var b = try Set<Int>.Ordered.Fixed(capacity: 8)
        try b.insert(2); try b.insert(3); try b.insert(4)

        #expect(toArray(a.union(b)) == [1, 2, 3, 4])
        #expect(toArray(a.intersection(b)) == [2, 3])
        #expect(toArray(a.subtract(b)) == [1])
        #expect(toArray(a.symmetricDifference(b)) == [1, 4])
    }

    @Test
    func `Static algebra defaults`() throws {
        var a = Set<Int>.Ordered.Static<8>()
        try a.insert(1); try a.insert(2); try a.insert(3)
        var b = Set<Int>.Ordered.Static<8>()
        try b.insert(2); try b.insert(3); try b.insert(4)

        let unionResult = toArray(a.union(b))
        #expect(unionResult == [1, 2, 3, 4])
        let intersectionResult = toArray(a.intersection(b))
        #expect(intersectionResult == [2, 3])
        let subtractResult = toArray(a.subtract(b))
        #expect(subtractResult == [1])
        let symDiffResult = toArray(a.symmetricDifference(b))
        #expect(symDiffResult == [1, 4])
    }

    @Test
    func `Small algebra defaults`() {
        var a = Set<Int>.Ordered.Small<8>()
        a.insert(1); a.insert(2); a.insert(3)
        var b = Set<Int>.Ordered.Small<8>()
        b.insert(2); b.insert(3); b.insert(4)

        let unionResult = toArray(a.union(b))
        #expect(unionResult == [1, 2, 3, 4])
        let intersectionResult = toArray(a.intersection(b))
        #expect(intersectionResult == [2, 3])
        let subtractResult = toArray(a.subtract(b))
        #expect(subtractResult == [1])
        let symDiffResult = toArray(a.symmetricDifference(b))
        #expect(symDiffResult == [1, 4])
    }
}
