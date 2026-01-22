# Experiments Index

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| set-ordered-consuming-iteration | Verify consuming iteration APIs feasibility for Set.Ordered | 2026-01-22 | Swift 6.2.3 | CONFIRMED (implemented) |
| consuming-semantics | Investigate if ownership modifiers can replace naming conventions | 2026-01-22 | Swift 6.2.3 | CONFIRMED (naming required) |

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

### consuming-semantics

**Outcome**: Investigation confirmed that Swift 6.2 does NOT support ownership-based method overloading. The current naming convention is REQUIRED.

**Questions investigated**:
- [Q1] Can we overload methods by ownership modifier (borrowing vs consuming)? → **NO** - "invalid redeclaration" error
- [Q2] Can consuming func forEach coexist with borrowing func forEach? → **NO** - Same signature, different ownership = redeclaration error
- [Q3] Does the compiler disambiguate based on call-site context? → **NO** - Reports "ambiguous use" even with different return types
- [Q4] Can closure parameter ownership disambiguate? → **NO** - `(borrowing Element)` vs `(consuming Element)` = ambiguous
- [Q5] What about property vs consuming method with same name? → **NO** - "invalid redeclaration" error
- [Q6] Can ~Copyable types conform to Sequence? → **NO** - Sequence requires Copyable conformance

**Conclusion**: The naming convention (`consumingForEach`, `makeConsumingIterator`) is REQUIRED by Swift's language constraints for Copyable types and provides consistency across all variants.

**Alternative patterns explored**:
- Namespace accessor pattern: `container.consuming().forEach { }` works but requires method (not property) for ~Copyable types
- Different names pattern: `forEach()` vs `consumingForEach()` - the chosen approach

**Recommendation**: Current API design in Set.Ordered is CORRECT. No changes needed.
