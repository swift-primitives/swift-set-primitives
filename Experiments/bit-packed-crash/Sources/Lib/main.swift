// Status: DEFERRED -- compiler SIL crash investigation: synthesized Equatable for nested type in conditional extension of ~Copyable enum, status PENDING in original header.
// Revalidated: resumption -- revalidate on each new Swift toolchain per [META-006]; capture FIXED verdict if compiler accepts the original repro per [EXP-006]. (Phase 1b stale-triage 2026-04-30)
// ===----------------------------------------------------------------------===//
// Experiment: bit-packed-crash
// ===----------------------------------------------------------------------===//
//
// HYPOTHESIS: Synthesized Equatable for nested type in conditional extension
//             of ~Copyable enum crashes Swift compiler during SIL generation.
//
// TRIGGER: Set<Bit>.Packed.Bounded : Equatable crashes in __derived_struct_equals
//
// METHODOLOGY: [EXP-004a] Incremental Construction
//
// RESULT: [PENDING]
//
// ===----------------------------------------------------------------------===//

// V1: Minimal ~Copyable enum with conditional extension containing nested type
// Attempt to reproduce the crash

/// A minimal protocol to satisfy the constraint
public protocol P: ~Copyable {
    var hashValue: Int { get }
}

/// A copyable type that conforms to P
public struct Marker: P, Sendable {
    public var hashValue: Int { 0 }
    public init() {}
}

/// ~Copyable namespace enum (like Set<Element>)
public enum Container<Element: P & ~Copyable>: ~Copyable {}

/// Conditional extension (like extension Set where Element == Bit)
extension Container where Element == Marker {
    /// Outer struct (like Set<Bit>.Packed)
    public struct Outer: Sendable {
        public var storage: ContiguousArray<UInt>

        public init() {
            self.storage = []
        }
    }
}

/// Nested type in separate extension (like Set<Bit>.Packed.Bounded)
extension Container<Marker>.Outer {
    public struct Bounded: Sendable {
        public var storage: ContiguousArray<UInt>
        public let capacity: Int

        public init(capacity: Int) {
            self.storage = ContiguousArray(repeating: 0, count: capacity)
            self.capacity = capacity
        }
    }
}

// V1a: Add synthesized Equatable - this is the crash trigger
extension Container<Marker>.Outer.Bounded: Equatable {}
