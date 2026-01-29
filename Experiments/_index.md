# Experiments Index

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| set-ordered-consuming-iteration | Verify consuming iteration APIs feasibility for Set.Ordered | 2026-01-22 | Swift 6.2.3 | CONFIRMED (implemented) |
| consuming-semantics | Investigate if ownership modifiers can replace naming conventions | 2026-01-22 | Swift 6.2.3 | CONFIRMED (naming required) |
| swift-testing-crash | Investigate crash/non-discovery of @Suite in generic type extensions | 2026-01-22 | Swift 6.2.3 | CONFIRMED (filed #1508) |

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

**Files added for Set.Ordered.Fixed**:
- `Set.Ordered.Fixed.Consuming.swift`
- `Set.Ordered.Fixed.Consuming.Iterator.swift`
- `Set.Ordered.Fixed.Consuming.Counted.swift`

**Files added for Set.Ordered.Static**:
- `Set.Ordered.Static.Consuming.swift`
- `Set.Ordered.Static.Consuming.Iterator.swift`
- `Set.Ordered.Static.Consuming.Counted.swift`

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

### swift-testing-crash

**Outcome**: Bug confirmed, issue filed to swiftlang/swift-testing.

**Issue**: [swiftlang/swift-testing#1508](https://github.com/swiftlang/swift-testing/issues/1508)

**Problem**: `@Test` and `@Suite` macros compile without error inside extensions of concrete generic type specializations (e.g., `extension Container<Int>`), but the resulting tests are silently invisible to `swift test list` and never execute.

**Conditions required** (all three must be present):
1. Generic struct (e.g., `struct Container<T> {}`)
2. Concrete specialization extension (e.g., `extension Container<Int>`)
3. `@Test` macro applied to method inside that extension

**Reproduction**:
```swift
struct Container<T> {}

extension Container<Int> {
    @Suite struct Tests {
        @Test("never discovered")
        func bug() { #expect(Bool(true)) }
    }
}
```

**Workaround**: Use parallel namespace pattern instead of type extension for generic types:
```swift
@Suite("Container<Int>")
struct ContainerIntTests {
    @Test func test() { ... }
}
```

**Impact**: Prevents using the `Type.Test` extension pattern for generic types. Must use parallel `TypeTests` pattern instead.
