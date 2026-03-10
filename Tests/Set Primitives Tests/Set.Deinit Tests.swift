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

@Suite("Set - Deinit")
struct SetDeinitTests {

    final class Tracker: @unchecked Sendable {
        private var _storage: [Int] = []
        var deinitCount: Int { _storage.count }
        func append(_ id: Int) { _storage.append(id) }
    }

    /// A tracked element with deinit that also conforms to Hash.Protocol.
    /// Uses a class (reference type) so Set can store it — the deinit fires
    /// when the last reference is released.
    final class TrackedElement: Hash.`Protocol`, @unchecked Sendable {
        let id: Int
        let tracker: Tracker
        init(_ id: Int, tracker: Tracker) { self.id = id; self.tracker = tracker }
        deinit { tracker.append(id) }
        static func == (lhs: borrowing TrackedElement, rhs: borrowing TrackedElement) -> Bool {
            lhs.id == rhs.id
        }
        borrowing func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    // MARK: - Set.Ordered.Static

    @Test
    func `Static deinit destroys all elements`() throws {
        let tracker = Tracker()
        do {
            var set = Set<TrackedElement>.Ordered.Static<8>()
            try set.insert(TrackedElement(1, tracker: tracker))
            try set.insert(TrackedElement(2, tracker: tracker))
            try set.insert(TrackedElement(3, tracker: tracker))
        }
        #expect(tracker.deinitCount == 3)
    }

    @Test
    func `Static empty deinit does not crash`() {
        do {
            let _ = Set<TrackedElement>.Ordered.Static<8>()
        }
    }

    // MARK: - Set.Ordered.Small

    @Test
    func `Small deinit destroys all elements`() {
        let tracker = Tracker()
        do {
            var set = Set<TrackedElement>.Ordered.Small<8>()
            set.insert(TrackedElement(1, tracker: tracker))
            set.insert(TrackedElement(2, tracker: tracker))
            set.insert(TrackedElement(3, tracker: tracker))
        }
        #expect(tracker.deinitCount == 3)
    }

    @Test
    func `Small empty deinit does not crash`() {
        do {
            let _ = Set<TrackedElement>.Ordered.Small<8>()
        }
    }
}
