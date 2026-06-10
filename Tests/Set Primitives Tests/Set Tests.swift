import Set_Primitives
import Hash_Table_Primitives_Test_Support
import Buffer_Primitives_Test_Support
import Hash_Table_Primitive
import Hash_Indexed_Primitive
import Hash_Primitives
import Hash_Primitives_Standard_Library_Integration
import Buffer_Primitive
import Buffer_Linear_Primitive
import Storage_Primitive
import Storage_Contiguous_Primitives
import Memory_Heap_Primitives
import Memory_Allocator_Primitive
import Shared_Primitive
import Index_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Ordinal_Primitives_Standard_Library_Integration
import Testing

// The column-keyed set suite: the ordered hashed column direct + Shared-wrapped.

private typealias HeapStorage<E: ~Copyable> =
    Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>

private typealias OrderedColumn<E: Hash.Key & ~Copyable> =
    Hash.Indexed<Buffer<HeapStorage<E>>.Linear>

private typealias MoveSet<E: Hash.Key & ~Copyable> = Set<OrderedColumn<E>>
private typealias CoWSet<E: Hash.Key & SendableMetatype> = Set<Shared<E, OrderedColumn<E>>>

// MARK: - [DS-024] + coherence (the Shared composite is this family's NEW column)

@Suite
struct SetColumnLawTests {

    @Test
    func `the shared ordered-hashed column obeys the seam ledger laws`() {
        let violations = Seam.Ledger.violations(
            makeEmpty: { Shared(OrderedColumn<Int>(minimumCapacity: Index<Int>.Count(4))) },
            element: { $0 }
        )
        #expect(violations.isEmpty, "\(violations)")
    }

    @Test
    func `coherence holds through the set surface, both columns`() {
        var direct = MoveSet<Int>(minimumCapacity: 4)
        var i = 0
        while i < 16 {
            direct.insert(i &* 3)
            i += 1
        }
        _ = direct.remove(9)
        _ = direct.remove(0)
        let directViolations = direct.take().checkCoherence()
        #expect(directViolations.isEmpty, "\(directViolations)")
    }
}

extension Hash.Indexed<Buffer<HeapStorage<Int>>.Linear> {
    fileprivate borrowing func checkCoherence() -> [String] {
        Hash.Coherence.violations(self)
    }
}

// MARK: - Core membership (both columns)

@Suite(.serialized)
struct SetCoreTests {

    @Test
    func `insert, contains, duplicate hand-back, remove, counts`() {
        var s = MoveSet<Int>(minimumCapacity: 4)
        let isEmpty = s.isEmpty
        #expect(isEmpty)
        let first = s.insert(10)
        #expect(first == nil)
        let dup = s.insert(10)
        #expect(dup == 10)
        s.insert(20)
        s.insert(30)
        let has = s.contains(20), hasNot = s.contains(40)
        #expect(has)
        #expect(!hasNot)
        let removed = s.remove(20)
        #expect(removed == 20)
        let absent = s.remove(20)
        #expect(absent == nil)
        let n = s.count
        #expect(n == Index<Int>.Count(2))
    }

    @Test
    func `iteration is insertion-ordered across growth and removal`() {
        var s = MoveSet<Int>(minimumCapacity: 2)
        var i = 0
        while i < 12 {
            s.insert(i)
            i += 1
        }
        _ = s.remove(5)
        var seen: [Int] = []
        s.forEach { seen.append($0) }
        #expect(seen == [0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11])
    }

    @Test
    func `removeAll empties; reuse works; direct clone detaches`() {
        var s = MoveSet<Int>(minimumCapacity: 4)
        s.insert(1)
        s.insert(2)
        var c = s.clone()
        _ = c.remove(1)
        let mineHas = s.contains(1), theirsHas = c.contains(1)
        #expect(mineHas)
        #expect(!theirsHas)
        s.removeAll()
        let isEmpty = s.isEmpty
        #expect(isEmpty)
        s.insert(7)
        let has7 = s.contains(7)
        #expect(has7)
    }
}

// MARK: - CoW value semantics (the Shared composite column)

@Suite(.serialized)
struct SetCoWTests {

    @Test
    func `copies share until mutation; inserts detach through the box`() {
        var a = CoWSet<Int>(minimumCapacity: 4)
        a.insert(1)
        let b = a                                // S5: Set is Copyable because S is
        a.insert(2)                              // withUnique(consuming:) detaches first
        let mine = a.count, theirs = b.count
        #expect(mine == Index<Int>.Count(2))
        #expect(theirs == Index<Int>.Count(1))
        let aHas2 = a.contains(2), bHas2 = b.contains(2)
        #expect(aHas2)
        #expect(!bHas2)
    }

    @Test
    func `removal detaches; the sibling keeps the member; generic clone detaches`() {
        var a = CoWSet<Int>(minimumCapacity: 4)
        a.insert(1)
        a.insert(2)
        let b = a
        let removed = a.remove(1)
        #expect(removed == 1)
        let bStillHas = b.contains(1)
        #expect(bStillHas)

        var c = a.clone()
        c.insert(9)
        let aHas9 = a.contains(9), cHas9 = c.contains(9)
        #expect(!aHas9)
        #expect(cHas9)
    }

    @Test
    func `removeAll detaches to a fresh box; the sibling is untouched`() {
        var a = CoWSet<Int>(minimumCapacity: 4)
        a.insert(1)
        let b = a
        a.removeAll()
        let aEmpty = a.isEmpty, bHas = b.contains(1)
        #expect(aEmpty)
        #expect(bHas)
    }
}

// MARK: - Move-only members + teardown

@Suite(.serialized)
struct SetTeardownTests {

    @Test
    func `move-only members flow through and tear down exactly once`() {
        SetProbe.reset()
        do {
            var s = MoveSet<SetItem>(minimumCapacity: 4)
            s.insert(SetItem(1))
            s.insert(SetItem(2))
            let has = s.contains(SetItem(2))
            #expect(has)
            if let removed: SetItem = s.remove(SetItem(1)) {
                let id = removed.id
                #expect(id == 1)
            } else {
                Issue.record("expected the removed member")
            }
        }
        let all = SetProbe.destroyedSorted
        let twos = all.filter { $0 == 2 }.count
        #expect(twos == 2)                       // the live member + the contains() probe argument
    }

    @Test
    func `the boxed move-only lane tears down via the box drain`() {
        SetProbe2.reset()
        do {
            var s = Set<Shared<SetItem2, OrderedColumn<SetItem2>>>(minimumCapacity: 4)
            s.insert(SetItem2(7))
            s.insert(SetItem2(8))
            let n = s.count
            #expect(n == Index<SetItem2>.Count(2))
        }
        let all = SetProbe2.destroyedSorted
        #expect(all == [7, 8])
    }
}

private struct SetItem: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { SetProbe.recordDestroy(id) }
}

extension SetItem: Hash.`Protocol` {
    borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: borrowing SetItem, rhs: borrowing SetItem) -> Bool {
        lhs.id == rhs.id
    }
}

private enum SetProbe {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}

private struct SetItem2: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { SetProbe2.recordDestroy(id) }
}

extension SetItem2: Hash.`Protocol` {
    borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: borrowing SetItem2, rhs: borrowing SetItem2) -> Bool {
        lhs.id == rhs.id
    }
}

private enum SetProbe2 {
    nonisolated(unsafe) static var _destroyed: [Int] = []
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}

// MARK: - Sendable smoke

@Suite
struct SetSendableTests {

    @Test
    func `sendable composes through both columns`() {
        let a = MoveSet<Int>(minimumCapacity: 1)
        requireSendable(a)
        let b = CoWSet<Int>(minimumCapacity: 1)
        requireSendable(b)
        #expect(Bool(true))
    }
}

private func requireSendable<T: Sendable & ~Copyable>(_ value: borrowing T) {}
