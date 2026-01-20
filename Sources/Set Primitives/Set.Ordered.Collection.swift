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

// MARK: - Sequence

extension Set_Primitives.Set.Ordered: Sequence {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        var index: Int

        @usableFromInline
        let storage: ElementStorage

        @usableFromInline
        let count: Int

        @usableFromInline
        init(_ ordered: Set_Primitives.Set<Element>.Ordered) {
            self.index = 0
            self.storage = ordered._elementStorage
            self.count = storage.header
        }

        @inlinable
        public mutating func next() -> Element? {
            guard index < count else { return nil }
            let element = storage._readElement(at: index)
            index += 1
            return element
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(self)
    }
}

// Note: @unchecked because we store a reference to ElementStorage (a class).
// This is safe because the iterator only reads from the storage and doesn't escape it.
extension Set_Primitives.Set.Ordered.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: - Collection

extension Set_Primitives.Set.Ordered: Collection {
    public typealias Index = Int

    @inlinable
    public var startIndex: Index { 0 }

    @inlinable
    public var endIndex: Index { count }

    @inlinable
    public func index(after i: Index) -> Index {
        i + 1
    }
}

// MARK: - BidirectionalCollection

extension Set_Primitives.Set.Ordered: BidirectionalCollection {
    @inlinable
    public func index(before i: Index) -> Index {
        i - 1
    }
}

// MARK: - RandomAccessCollection

extension Set_Primitives.Set.Ordered: RandomAccessCollection {
    @inlinable
    public func distance(from start: Index, to end: Index) -> Int {
        end - start
    }

    @inlinable
    public func index(_ i: Index, offsetBy distance: Int) -> Index {
        i + distance
    }

    @inlinable
    public func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        let result = i + distance
        if distance >= 0 {
            return result <= limit ? result : nil
        } else {
            return result >= limit ? result : nil
        }
    }
}
