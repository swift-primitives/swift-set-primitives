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

import Set_Primitives
import Set_Primitive
import Hash_Primitives
import Hash_Primitives_Standard_Library_Integration
import Hash_Table_Primitive
import Hash_Indexed_Primitive
import Buffer_Primitive
import Buffer_Linear_Primitive
import Storage_Contiguous_Primitives
import Memory_Heap_Primitives
import Memory_Allocator_Primitive
import Shared_Primitive
import Index_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Ordinal_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Cardinal_Primitives

// The ratified columns, spelled as the package's own test suite spells them.

typealias HeapStorage<E: ~Copyable> =
    Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>

typealias OrderedColumn<E: Hash.Key & ~Copyable> =
    Hash.Indexed<Buffer<HeapStorage<E>>.Linear>

typealias MoveSet<E: Hash.Key & ~Copyable> = Set<OrderedColumn<E>>

typealias CoWSet<E: Hash.Key & SendableMetatype> = Set<Shared<E, OrderedColumn<E>>>

extension Bench {
    /// The order-preserving remove curve uses denser scales: removing the
    /// OLDEST element shifts the whole dense buffer, so cost grows with n.
    static let curveSizes: [Int] = [16, 256, 4_096, 65_536]

    /// Typed count from a runtime size via the non-throwing `UInt` lane.
    static func count<E>(_ n: Int) -> Index_Primitives.Index<E>.Count {
        Index_Primitives.Index<E>.Count(Cardinal(UInt(n)))
    }

    /// Shapes per the inventory (vs `Swift.Set`, the unordered baseline):
    ///
    /// - `insert.zero`: build n from zero capacity (hashing + growth/re-seed
    ///   included), teardown in-batch on every subject alike.
    /// - `lookup.hit` / `lookup.miss`: `contains` over present / absent keys.
    /// - `frontEvict.steady`: at occupancy n, remove the OLDEST element +
    ///   insert a fresh key (one op = the pair) — the order-preserving remove
    ///   pays its full dense shift; `Swift.Set` pays O(1). THE CURVE.
    /// - `backEvict.steady`: remove the NEWEST + insert — the shift-free
    ///   control; isolates hash-removal cost from the order shift.
    /// - `iterate.sum`: `forEach` in insertion order vs stdlib's bucket scan.
    static func setCases() -> [Result] {
        var results: [Result] = []

        for n in sizes {
            let reps = Swift.max(1, structureOpsTarget / n)
            let buildOps = reps * n
            let seed = opaque(0)

            results.append(Result(
                name: "insert.zero", subject: "tower.direct", n: n, opsPerBatch: buildOps,
                perOpNs: sample(opsPerBatch: buildOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var s = MoveSet<Int>(minimumCapacity: .zero)
                        for i in 0..<n { _ = s.insert(i &+ seed) }
                        acc &+= s.contains(seed) ? 1 : 0
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "insert.zero", subject: "tower.cow", n: n, opsPerBatch: buildOps,
                perOpNs: sample(opsPerBatch: buildOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var s = CoWSet<Int>(minimumCapacity: .zero)
                        for i in 0..<n { _ = s.insert(i &+ seed) }
                        acc &+= s.contains(seed) ? 1 : 0
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "insert.zero", subject: "stdlib", n: n, opsPerBatch: buildOps,
                perOpNs: sample(opsPerBatch: buildOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var s = Swift.Set<Int>()
                        for i in 0..<n { s.insert(i &+ seed) }
                        acc &+= s.contains(seed) ? 1 : 0
                    }
                    sink(acc)
                }
            ))

            // Lookup setup: subjects filled with 0..<n outside timed regions;
            // hit keys 0..<n, miss keys n..<2n.
            let passes = Swift.max(1, (elementOpsTarget / 4) / n)
            let lookupOps = passes * n

            var s = MoveSet<Int>(minimumCapacity: count(n))
            for i in 0..<n { _ = s.insert(i) }
            var c = CoWSet<Int>(minimumCapacity: count(n))
            for i in 0..<n { _ = c.insert(i) }
            var sl = Swift.Set<Int>(minimumCapacity: n)
            for i in 0..<n { sl.insert(i) }

            for (label, lo) in [("lookup.hit", 0), ("lookup.miss", n)] {
                results.append(Result(
                    name: label, subject: "tower.direct", n: n, opsPerBatch: lookupOps,
                    perOpNs: sample(opsPerBatch: lookupOps) {
                        var hits = 0
                        for _ in 0..<passes {
                            for k in lo..<(lo + n) where s.contains(k) { hits &+= 1 }
                        }
                        sink(hits)
                    }
                ))

                results.append(Result(
                    name: label, subject: "tower.cow", n: n, opsPerBatch: lookupOps,
                    perOpNs: sample(opsPerBatch: lookupOps) {
                        var hits = 0
                        for _ in 0..<passes {
                            for k in lo..<(lo + n) where c.contains(k) { hits &+= 1 }
                        }
                        sink(hits)
                    }
                ))

                results.append(Result(
                    name: label, subject: "stdlib", n: n, opsPerBatch: lookupOps,
                    perOpNs: sample(opsPerBatch: lookupOps) {
                        var hits = 0
                        for _ in 0..<passes {
                            for k in lo..<(lo + n) where sl.contains(k) { hits &+= 1 }
                        }
                        sink(hits)
                    }
                ))
            }

            let iterOps = passes * n

            results.append(Result(
                name: "iterate.sum", subject: "tower.direct", n: n, opsPerBatch: iterOps,
                perOpNs: sample(opsPerBatch: iterOps) {
                    var sum = 0
                    for _ in 0..<passes {
                        s.forEach { sum &+= $0 }
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "iterate.sum", subject: "tower.cow", n: n, opsPerBatch: iterOps,
                perOpNs: sample(opsPerBatch: iterOps) {
                    var sum = 0
                    for _ in 0..<passes {
                        c.forEach { sum &+= $0 }
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "iterate.sum", subject: "stdlib", n: n, opsPerBatch: iterOps,
                perOpNs: sample(opsPerBatch: iterOps) {
                    var sum = 0
                    for _ in 0..<passes {
                        for k in sl { sum &+= k }
                    }
                    sink(sum)
                }
            ))
        }

        // Flat churn (no rank surface => a single rolling remove+insert row;
        // the B-7 Θ(capacity) sweep applies to THIS family too — same combinator).
        for n in curveSizes {
            let pairs = Swift.max(16, copiedSlotsTarget / n)

            var s = MoveSet<Int>(minimumCapacity: count(n))
            for i in 0..<n { _ = s.insert(i) }
            var low = 0
            var high = n

            results.append(Result(
                name: "churn.steady", subject: "tower.direct", n: n, opsPerBatch: pairs,
                perOpNs: sample(opsPerBatch: pairs) {
                    var acc = 0
                    for _ in 0..<pairs {
                        acc &+= s.remove(low) ?? 0
                        _ = s.insert(high)
                        low &+= 1
                        high &+= 1
                    }
                    sink(acc)
                }
            ))

            var c = CoWSet<Int>(minimumCapacity: count(n))
            for i in 0..<n { _ = c.insert(i) }
            var clow = 0
            var chigh = n

            results.append(Result(
                name: "churn.steady", subject: "tower.cow", n: n, opsPerBatch: pairs,
                perOpNs: sample(opsPerBatch: pairs) {
                    var acc = 0
                    for _ in 0..<pairs {
                        acc &+= c.remove(clow) ?? 0
                        _ = c.insert(chigh)
                        clow &+= 1
                        chigh &+= 1
                    }
                    sink(acc)
                }
            ))

            var sl = Swift.Set<Int>(minimumCapacity: n)
            for i in 0..<n { sl.insert(i) }
            var slow = 0
            var shigh = n
            let stdPairs = 1 << 15

            results.append(Result(
                name: "churn.steady", subject: "stdlib", n: n, opsPerBatch: stdPairs,
                perOpNs: sample(opsPerBatch: stdPairs) {
                    var acc = 0
                    for _ in 0..<stdPairs {
                        acc &+= sl.remove(slow) ?? 0
                        sl.insert(shigh)
                        slow &+= 1
                        shigh &+= 1
                    }
                    sink(acc)
                }
            ))
        }

        // The wipe rows (removeAll(keepingCapacity:) — build+wipe per rep; the
        // build.zero rows above are the subtraction control).
        for n in [1_024, 65_536] {
            let reps = Swift.max(8, structureOpsTarget / n)
            let wipeOps = reps * n
            let seed = opaque(0)

            results.append(Result(
                name: "buildWipe.keep", subject: "tower.direct", n: n, opsPerBatch: wipeOps,
                perOpNs: sample(opsPerBatch: wipeOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var s = MoveSet<Int>(minimumCapacity: count(n))
                        for i in 0..<n { _ = s.insert(i &+ seed) }
                        s.removeAll(keepingCapacity: true)
                        acc &+= s.isEmpty ? 1 : 0
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "buildWipe.keep", subject: "tower.cow", n: n, opsPerBatch: wipeOps,
                perOpNs: sample(opsPerBatch: wipeOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var c = CoWSet<Int>(minimumCapacity: count(n))
                        for i in 0..<n { _ = c.insert(i &+ seed) }
                        c.removeAll(keepingCapacity: true)
                        acc &+= c.isEmpty ? 1 : 0
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "buildWipe.keep", subject: "stdlib", n: n, opsPerBatch: wipeOps,
                perOpNs: sample(opsPerBatch: wipeOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var sl = Swift.Set<Int>(minimumCapacity: n)
                        for i in 0..<n { sl.insert(i &+ seed) }
                        sl.removeAll(keepingCapacity: true)
                        acc &+= sl.isEmpty ? 1 : 0
                    }
                    sink(acc)
                }
            ))
        }

        return results
    }
}
