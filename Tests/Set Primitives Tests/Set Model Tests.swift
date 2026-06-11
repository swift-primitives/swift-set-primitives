import Set_Primitives
import Hash_Table_Primitives_Test_Support
public import Buffer_Primitives_Test_Support
import Hash_Primitives
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

// The W3 set model suite (arc-2): seeded op streams through the ADT's lawful
// surface on BOTH columns, against an insertion-ordered reference. The bare
// set's only read doors are membership and iteration, so `forEach` order
// equivalence IS the per-slot oracle. The Shared lane runs the sibling fleet
// (forks copy the model; every sibling audits against its own fork — CoW leaks
// fail at the op) with REFCOUNTED censused members: deaths are refcount-final,
// so exactness is asserted as the end-of-scope birth/death multiset. The direct
// lane uses the move-only fixture; teardown exactness is the end multiset
// (probes, hand-backs, removals, wipes, dense-growth relocations, and the final
// drop all account identically).
//
// Determinism: generation reads MODEL state only. Shape constraint: B10 — each
// op is its own small method on a stream struct.

private typealias HeapStorage<E: ~Copyable> =
    Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>

private typealias OrderedColumn<E: Hash.Key & ~Copyable> =
    Hash.Indexed<Buffer<HeapStorage<E>>.Linear>

private typealias MoveSet<E: Hash.Key & ~Copyable> = Set<OrderedColumn<E>>
private typealias CoWSet<E: Hash.Key & SendableMetatype> = Set<Shared<E, OrderedColumn<E>>>

// MARK: - Fixtures: the hoisted move-only element gains the hashed key bound
// (consumer-side conformance; hash binds to `group` — controlled collisions);
// the fleet member is a refcounted censused class (deaths are refcount-final).

extension Model.Element.Tracked: @retroactive Hash.`Protocol` {
    public borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(group)
    }

    public static func == (lhs: borrowing Model.Element.Tracked, rhs: borrowing Model.Element.Tracked) -> Bool {
        lhs.id == rhs.id
    }
}

private final class Member {
    let id: Int
    let group: Int
    let serial: Int
    private let census: Model.Census

    init(id: Int, group: Int, census: Model.Census) {
        self.id = id
        self.group = group
        self.census = census
        self.serial = census.mint()
    }

    deinit {
        census.record(death: serial)
    }
}

extension Member: Hash.`Protocol` {
    borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(group)
    }

    static func == (lhs: borrowing Member, rhs: borrowing Member) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - The reference model: insertion-ordered membership

private struct Reference {
    var members: [(id: Int, group: Int)] = []
    var ids: Swift.Set<Int> = []
    var graveyard: [(id: Int, group: Int)] = []

    mutating func append(id: Int, group: Int) {
        members.append((id, group))
        ids.insert(id)
    }

    mutating func remove(at index: Int) {
        let member = members.remove(at: index)
        ids.remove(member.id)
        retire(member)
    }

    mutating func removeAll() {
        for member in members.prefix(4) { retire(member) }
        members.removeAll()
        ids.removeAll()
    }

    private mutating func retire(_ member: (id: Int, group: Int)) {
        graveyard.append(member)
        if graveyard.count > 8 {
            graveyard.removeFirst(graveyard.count - 8)
        }
    }
}

// MARK: - The direct move-only stream

private struct DirectStream: ~Copyable {
    var set: MoveSet<Model.Element.Tracked>
    var model = Reference()
    var rng: Model.Random
    var verdict: Model.Verdict
    var nextID = 0
    let collisionDivisor = 4
    let census: Model.Census

    init(seed: UInt64, census: Model.Census) {
        var rng = Model.Random(seed: seed)
        self.set = MoveSet<Model.Element.Tracked>(
            minimumCapacity: Index<Model.Element.Tracked>.Count(UInt(rng.below(17)))
        )
        self.rng = rng
        self.verdict = Model.Verdict(seed: seed)
        self.census = census
    }

    mutating func freshID() -> (id: Int, group: Int) {
        let minted = (nextID, nextID / collisionDivisor)
        nextID += 1
        return minted
    }

    func probe(_ member: (id: Int, group: Int)) -> Model.Element.Tracked {
        Model.Element.Tracked(id: member.id, group: member.group, census: census)
    }

    mutating func insertFresh() {
        let minted = freshID()
        verdict.record("insert id=\(minted.id) g=\(minted.group)")
        if let rejected = set.insert(probe(minted)) {
            verdict.diverged(["insert of fresh id \(rejected.id) was rejected as a duplicate"])
        } else {
            model.append(id: minted.id, group: minted.group)
        }
    }

    mutating func insertDuplicate() {
        let pick = model.members[rng.below(model.members.count)]
        verdict.record("dup id=\(pick.id)")
        if let rejected = set.insert(probe(pick)) {
            if rejected.id != pick.id {
                verdict.diverged(["duplicate hand-back id \(rejected.id), expected \(pick.id)"])
            }
        } else {
            verdict.diverged(["duplicate id \(pick.id) was inserted as fresh"])
        }
    }

    mutating func removePresent() {
        let index = rng.below(model.members.count)
        let pick = model.members[index]
        verdict.record("remove id=\(pick.id) @\(index)")
        if let removed = set.remove(probe(pick)) {
            if removed.id != pick.id {
                verdict.diverged(["remove(id \(pick.id)) returned id \(removed.id)"])
            }
            model.remove(at: index)
        } else {
            verdict.diverged(["remove(id \(pick.id)) found nothing for a live member"])
        }
    }

    mutating func removeAbsent() {
        let minted = freshID()
        verdict.record("absent id=\(minted.id)")
        if let removed = set.remove(probe(minted)) {
            verdict.diverged(["remove of never-inserted id \(minted.id) returned id \(removed.id)"])
        }
    }

    mutating func containsHit() {
        let pick = model.members[rng.below(model.members.count)]
        verdict.record("has id=\(pick.id)")
        if !set.contains(probe(pick)) {
            verdict.diverged(["live id \(pick.id) is not contained"])
        }
    }

    mutating func containsMiss() {
        let minted = freshID()
        verdict.record("miss id=\(minted.id)")
        if set.contains(probe(minted)) {
            verdict.diverged(["never-inserted id \(minted.id) is contained"])
        }
    }

    mutating func walkOrder() {
        verdict.record("walk \(model.members.count)")
        var seen: [Int] = []
        set.forEach { (member: borrowing Model.Element.Tracked) in seen.append(member.id) }
        let expected = model.members.map { $0.id }
        if seen != expected {
            verdict.diverged(["forEach walked \(seen), model insertion order \(expected)"])
        }
    }

    mutating func wipe() {
        let keep = rng.chance(50)
        verdict.record("wipe keep=\(keep)")
        set.removeAll(keepingCapacity: keep)
        model.removeAll()
    }

    func audit() -> [String] {
        var findings: [String] = []
        if set.count != Index<Model.Element.Tracked>.Count(UInt(model.members.count)) {
            findings.append("count: set \(set.count), model \(model.members.count)")
        }
        var seen: [Int] = []
        set.forEach { (member: borrowing Model.Element.Tracked) in seen.append(member.id) }
        let expected = model.members.map { $0.id }
        if seen != expected {
            findings.append("order: set \(seen), model \(expected)")
        }
        for retired in model.graveyard where !model.ids.contains(retired.id) {
            if set.contains(probe(retired)) {
                findings.append("retired id \(retired.id) (group \(retired.group)) is still reachable")
            }
        }
        return findings
    }

    mutating func step() {
        var branch = rng.below(100)
        if model.members.isEmpty, branch >= 30, branch < 90 { branch = 0 }

        switch branch {
        case 0..<30: insertFresh()
        case 30..<40: insertDuplicate()
        case 40..<62: removePresent()
        case 62..<66: removeAbsent()
        case 66..<82: containsHit()
        case 82..<88: containsMiss()
        case 88..<96: walkOrder()
        default: wipe()
        }
    }

    mutating func run() {
        let operations = Model.operations(default: 800)
        var op = 0
        while op < operations, verdict.isClean {
            step()
            if Model.shouldAudit(op: op, of: operations) {
                verdict.diverged(audit())
            }
            op += 1
        }
    }

    consuming func finish() -> Model.Verdict {
        verdict
    }
}

private func runDirectStream(seed: UInt64) -> Model.Verdict {
    let census = Model.Census()
    var stream = DirectStream(seed: seed, census: census)
    stream.run()
    var verdict = stream.finish()  // the set dies here

    if !census.isExact {
        verdict.findings.append(
            "teardown multiset broken: \(census.born.count) born vs \(census.died.count) died"
        )
    }
    return verdict
}

// MARK: - The Shared (CoW) sibling fleet

private struct FleetStream {
    var siblings: [CoWSet<Member>]
    var models: [Reference]
    var rng: Model.Random
    var verdict: Model.Verdict
    var nextID = 0
    let collisionDivisor = 4
    let census: Model.Census

    init(seed: UInt64, census: Model.Census) {
        var rng = Model.Random(seed: seed)
        self.siblings = [CoWSet<Member>(
            minimumCapacity: Index<Member>.Count(UInt(rng.below(9)))
        )]
        self.models = [Reference()]
        self.rng = rng
        self.verdict = Model.Verdict(seed: seed)
        self.census = census
    }

    mutating func freshID() -> (id: Int, group: Int) {
        let minted = (nextID, nextID / collisionDivisor)
        nextID += 1
        return minted
    }

    func probe(_ member: (id: Int, group: Int)) -> Member {
        Member(id: member.id, group: member.group, census: census)
    }

    mutating func fork() {
        let source = rng.below(siblings.count)
        verdict.record("fork ←\(source) (\(siblings.count + 1) siblings)")
        siblings.append(siblings[source])
        models.append(models[source])
    }

    mutating func drop() {
        let target = rng.below(siblings.count)
        verdict.record("drop \(target)")
        siblings.remove(at: target)
        models.remove(at: target)
    }

    mutating func insertFresh(into target: Int) {
        let minted = freshID()
        verdict.record("insert[\(target)] id=\(minted.id) g=\(minted.group)")
        if let rejected = siblings[target].insert(probe(minted)) {
            verdict.diverged(["insert of fresh id \(rejected.id) was rejected as a duplicate"])
        } else {
            models[target].append(id: minted.id, group: minted.group)
        }
    }

    mutating func insertDuplicate(into target: Int) {
        let pick = models[target].members[rng.below(models[target].members.count)]
        verdict.record("dup[\(target)] id=\(pick.id)")
        if let rejected = siblings[target].insert(probe(pick)) {
            if rejected.id != pick.id {
                verdict.diverged(["duplicate hand-back id \(rejected.id), expected \(pick.id)"])
            }
        } else {
            verdict.diverged(["duplicate id \(pick.id) was inserted as fresh on sibling \(target)"])
        }
    }

    mutating func removePresent(from target: Int) {
        let index = rng.below(models[target].members.count)
        let pick = models[target].members[index]
        verdict.record("remove[\(target)] id=\(pick.id) @\(index)")
        if let removed = siblings[target].remove(probe(pick)) {
            if removed.id != pick.id {
                verdict.diverged(["remove(id \(pick.id)) returned id \(removed.id)"])
            }
            models[target].remove(at: index)
        } else {
            verdict.diverged(["remove(id \(pick.id)) found nothing on sibling \(target)"])
        }
    }

    mutating func containsHit(on target: Int) {
        let pick = models[target].members[rng.below(models[target].members.count)]
        verdict.record("has[\(target)] id=\(pick.id)")
        if !siblings[target].contains(probe(pick)) {
            verdict.diverged(["live id \(pick.id) is not contained on sibling \(target)"])
        }
    }

    mutating func containsMiss(on target: Int) {
        let minted = freshID()
        verdict.record("miss[\(target)] id=\(minted.id)")
        if siblings[target].contains(probe(minted)) {
            verdict.diverged(["never-inserted id \(minted.id) is contained on sibling \(target)"])
        }
    }

    mutating func walkOrder(on target: Int) {
        verdict.record("walk[\(target)] \(models[target].members.count)")
        var seen: [Int] = []
        siblings[target].forEach { (member: borrowing Member) in seen.append(member.id) }
        let expected = models[target].members.map { $0.id }
        if seen != expected {
            verdict.diverged(["forEach on sibling \(target) walked \(seen), model \(expected)"])
        }
    }

    mutating func wipe(_ target: Int) {
        let keep = rng.chance(50)
        verdict.record("wipe[\(target)] keep=\(keep)")
        siblings[target].removeAll(keepingCapacity: keep)
        models[target].removeAll()
    }

    func audit() -> [String] {
        var findings: [String] = []
        for (index, model) in models.enumerated() {
            if siblings[index].count != Index<Member>.Count(UInt(model.members.count)) {
                findings.append("sibling \(index) count \(siblings[index].count), model \(model.members.count)")
            }
            var seen: [Int] = []
            siblings[index].forEach { (member: borrowing Member) in seen.append(member.id) }
            let expected = model.members.map { $0.id }
            if seen != expected {
                findings.append("sibling \(index) order \(seen), model \(expected)")
            }
        }
        return findings
    }

    mutating func step() {
        let target = rng.below(siblings.count)
        var branch = rng.below(100)
        if models[target].members.isEmpty, branch >= 16, branch < 92 { branch = 10 }

        switch branch {
        case 0..<10 where siblings.count < 4: fork()
        case 0..<10: insertFresh(into: target)
        case 10..<16: insertFresh(into: target)
        case 16..<26 where siblings.count > 1: drop()
        case 16..<26: insertFresh(into: target)
        case 26..<36: insertDuplicate(into: target)
        case 36..<56: removePresent(from: target)
        case 56..<72: containsHit(on: target)
        case 72..<78: containsMiss(on: target)
        case 78..<92: walkOrder(on: target)
        default: wipe(target)
        }
    }

    mutating func run() {
        let operations = Model.operations(default: 800)
        var op = 0
        while op < operations, verdict.isClean {
            step()
            if Model.shouldAudit(op: op, of: operations) {
                verdict.diverged(audit())
            }
            op += 1
        }
    }
}

private func runFleetStream(seed: UInt64) -> Model.Verdict {
    let census = Model.Census()
    var verdict: Model.Verdict
    do {
        var stream = FleetStream(seed: seed, census: census)
        stream.run()
        verdict = stream.verdict
    }  // every sibling dies here; refcounts fall to zero

    if !census.isExact {
        verdict.findings.append(
            "teardown multiset broken across the fleet: \(census.born.count) born vs \(census.died.count) died"
        )
    }
    return verdict
}

// MARK: - The suites

@Suite
struct `Set Model` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Set Model`.Integration {
    @Test(arguments: Model.seeds(default: [0x5E70_0001, 0x5E70_0002]))
    func `direct move-only stream: membership, order, and exact teardown`(seed: UInt64) {
        let verdict = runDirectStream(seed: seed)
        #expect(verdict.isClean, Comment(rawValue: verdict.report))
    }

    @Test(arguments: Model.seeds(default: [0xF1EE_0001, 0xF1EE_0002, 0xF1EE_0003]))
    func `shared sibling fleet: every sibling tracks its own fork; refcounts end exact`(seed: UInt64) {
        let verdict = runFleetStream(seed: seed)
        #expect(verdict.isClean, Comment(rawValue: verdict.report))
    }
}

extension `Set Model`.Unit {
    @Test
    func `direct clone detaches and stays order-coherent`() {
        var set = MoveSet<Model.Element.Tracked>(minimumCapacity: Index<Model.Element.Tracked>.Count(4))
        let census = Model.Census()
        set.insert(Model.Element.Tracked(id: 1, group: 0, census: census))
        set.insert(Model.Element.Tracked(id: 2, group: 0, census: census))
        // The direct clone needs Copyable elements, so the clone check rides the
        // Copyable fleet member instead.
        var original = CoWSet<Member>(minimumCapacity: Index<Member>.Count(4))
        original.insert(Member(id: 10, group: 1, census: census))
        original.insert(Member(id: 11, group: 1, census: census))
        var copy = original
        _ = copy.remove(Member(id: 10, group: 1, census: census))
        let copyHas = copy.contains(Member(id: 10, group: 1, census: census))
        let originalHas = original.contains(Member(id: 10, group: 1, census: census))
        #expect(!copyHas)
        #expect(originalHas)
        var order: [Int] = []
        original.forEach { (member: borrowing Member) in order.append(member.id) }
        #expect(order == [10, 11])
    }
}

extension `Set Model`.`Edge Case` {
    @Test
    func `duplicate hand-back returns the argument instance through the set door`() {
        let census = Model.Census()
        do {
            var set = MoveSet<Model.Element.Tracked>(minimumCapacity: Index<Model.Element.Tracked>.Count(4))
            set.insert(Model.Element.Tracked(id: 1, group: 0, census: census))  // serial 0
            if let rejected = set.insert(Model.Element.Tracked(id: 1, group: 0, census: census)) {  // serial 1
                let serial = rejected.serial
                #expect(serial == 1)
            } else {
                Issue.record("expected the duplicate to be handed back")
            }
            let diedMid = census.died.sorted()
            #expect(diedMid == [1])
        }
        let exact = census.isExact
        #expect(exact)
    }

    @Test
    func `removeAll on one sibling leaves the other's members intact`() {
        let census = Model.Census()
        do {
            var first = CoWSet<Member>(minimumCapacity: Index<Member>.Count(4))
            first.insert(Member(id: 1, group: 0, census: census))
            first.insert(Member(id: 2, group: 0, census: census))
            var second = first

            second.removeAll()

            let secondEmpty = second.isEmpty
            #expect(secondEmpty)
            let firstHasOne = first.contains(Member(id: 1, group: 0, census: census))
            let firstHasTwo = first.contains(Member(id: 2, group: 0, census: census))
            #expect(firstHasOne)
            #expect(firstHasTwo)
        }
        let exact = census.isExact
        #expect(exact)
    }
}
