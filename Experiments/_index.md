# Experiments Index

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| set-ordered-consuming-iteration | Verify consuming iteration APIs feasibility for Set.Ordered | 2026-01-22 | Swift 6.2.3 | CONFIRMED (implemented) |

## Notes

### set-ordered-consuming-iteration

**Outcome**: Feature implemented in `Set_Primitives`.

**Key findings**:
- `~Copyable` iterators work correctly for consuming iteration
- Tuples cannot contain `~Copyable` elements (Swift 6.2 limitation) - use struct wrapper instead
- Compiler crash workaround: delegate deinit cleanup to helper method on storage class

**Files added for Set.Ordered**:
- `Set.Ordered.Consuming.swift` - namespace enum + consuming methods
- `Set.Ordered.Consuming.Iterator.swift` - `~Copyable` iterator
- `Set.Ordered.Consuming.Counted.swift` - count + iterator wrapper

**Files added for Set.Ordered.Bounded**:
- `Set.Ordered.Bounded.Consuming.swift`
- `Set.Ordered.Bounded.Consuming.Iterator.swift`
- `Set.Ordered.Bounded.Consuming.Counted.swift`

**Files added for Set.Ordered.Inline**:
- `Set.Ordered.Inline.Consuming.swift`
- `Set.Ordered.Inline.Consuming.Iterator.swift`
- `Set.Ordered.Inline.Consuming.Counted.swift`

**Files added for Set.Ordered.Small**:
- `Set.Ordered.Small.Consuming.swift`
- `Set.Ordered.Small.Consuming.Iterator.swift`
- `Set.Ordered.Small.Consuming.Counted.swift`
