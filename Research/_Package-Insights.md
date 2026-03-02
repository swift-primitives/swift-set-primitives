# Set Primitives Insights

<!--
---
title: Set Primitives Insights
version: 1.0.0
last_updated: 2026-01-22
applies_to: [swift-set-primitives]
normative: false
---
-->
Design decisions, implementation patterns, and lessons learned specific to this package.

## Overview

This document captures insights that emerged during development of swift-set-primitives. These are not API requirements—they are recorded decisions and patterns that inform future work on this package.

**Document type**: Non-normative (recorded decisions, not requirements).

**Consolidation source**: Reflection entries tagged with `[Package: swift-set-primitives]`.

---

## Value Generics Cannot Carry Conditional Copyable

**Date**: 2026-01-21

**Context**: Implementing `Set<Bit>.Packed.Small<let inlineWordCount: Int>` and attempting to follow the `~Copyable` + conditional Copyable pattern from `Stack<Element>`.

### The Compiler Limitation

Swift's conditional Copyable pattern requires a **type** generic parameter to constrain on. The canonical pattern from `Stack<Element: ~Copyable>`:

```swift
public struct Stack<Element: ~Copyable>: ~Copyable { ... }
extension Stack: Copyable where Element: Copyable {}
extension Stack: Sequence where Element: Copyable { ... }
```

This works because `Element: Copyable` is a valid constraint—you're constraining a type parameter.

For `Set<Bit>.Packed.Small<let inlineWordCount: Int>`, the attempt was:

```swift
public struct Small<let inlineWordCount: Int>: ~Copyable, Sendable { ... }
extension Set<Bit>.Packed.Small: Copyable {}  // COMPILER ERROR
```

The error: `generic struct 'Small' required to be 'Copyable' but is marked with '~Copyable'`

The value generic parameter `inlineWordCount` provides no type to constrain on. There's nothing analogous to `where Element: Copyable` because `Int` isn't a type parameter—it's a value parameter. The compiler sees an unconditional request to add `Copyable` to a `~Copyable` type, which is forbidden.

### The Orthogonal Concerns

Value generics (`let N: Int`) and type generics (`Element: ~Copyable`) serve orthogonal purposes:

| Generic Kind | Purpose | Can Constrain Copyable? |
|--------------|---------|-------------------------|
| Type (`Element`) | Parameterize over types | `where Element: Copyable` |
| Value (`let N: Int`) | Parameterize over values | No type to constrain |

`Stack<Element>` needs conditional Copyable because `Element` might or might not be Copyable at instantiation time. The struct must be `~Copyable` to support move-only elements, then grants Copyable when elements permit.

`Small<let inlineWordCount: Int>` stores `InlineArray<inlineWordCount, UInt>`. The `UInt` is always trivial—Copyable isn't conditional on anything. There's no scenario where `Small<4>` should be Copyable but `Small<8>` shouldn't.

### The Correct Design Decision

For types with value generics that store only trivial data:

**DO NOT** declare `~Copyable` then try to add Copyable. It's syntactically impossible.

**DO** simply omit `~Copyable` entirely. The type is unconditionally Copyable because its storage is unconditionally trivial.

```swift
// Correct for Set<Bit>.Packed.Small
public struct Small<let inlineWordCount: Int>: Sendable {
    var _inlineStorage: InlineArray<inlineWordCount, UInt>
    var _heapStorage: ContiguousArray<UInt>?
    var _capacity: Int
    // All members are trivial → type is trivially Copyable
}
```

**Applies to**: All value-generic types with trivial storage.

---

## The ~Copyable Decision Framework

**Date**: 2026-01-21

**Context**: Deciding whether `Set<Bit>.Packed.Small` should be `~Copyable` after discovering the value generic limitation.

### When ~Copyable Is Required

A type MUST be declared `~Copyable` when:

1. **It stores generic elements that could be move-only**: `Stack<Element: ~Copyable>` stores `Element`, which might be `~Copyable` at instantiation.

2. **It has a deinit that must run**: `Stack.Small<Element>` has inline storage requiring element-by-element destruction. The deinit is essential, so the type must be `~Copyable` to prevent implicit copying that would skip it.

3. **Copying would violate semantics**: Types representing unique ownership (file handles, locks) where copy would create aliasing.

### When ~Copyable Is Wrong

A type should NOT be `~Copyable` when:

1. **Storage is unconditionally trivial**: `Set<Bit>.Packed.Small` stores `UInt` words and optional `ContiguousArray`—both always Copyable.

2. **There's no generic element type**: Fixed-type containers don't need conditional Copyable because there's nothing to condition on.

3. **Protocol conformances are needed**: `Sequence`, `Equatable`, `Hashable` require Copyable. A `~Copyable` type without conditional Copyable cannot conform.

4. **You want value semantics without manual implementation**: Copyable types get automatic memberwise copying. `~Copyable` types need explicit `borrowing`/`consuming` handling.

### The Design Table

| Storage Pattern | Generic Element? | Use ~Copyable? |
|-----------------|------------------|----------------|
| `Element` (might be ~Copyable) | Yes | Yes + conditional Copyable |
| `[Element]` (array of elements) | Yes | Yes + conditional Copyable |
| `UInt` / trivial types only | No | No, just use Sendable |
| Value generic (`let N: Int`) only | No | No, cannot condition Copyable |
| Inline storage with deinit | Yes | Yes (deinit requirement) |

`Set<Bit>.Packed.Small` falls in row 3/4: trivial storage, value generic, no generic element. The correct choice is plain `Sendable` without `~Copyable`.

**Applies to**: All container type design decisions.

---

## Documenting Deviation from Established Patterns

**Date**: 2026-01-21

**Context**: Adding documentation to `Set<Bit>.Packed.Small` explaining why it differs from `Stack.Small`.

### The Documentation Obligation

When a type deviates from an established pattern in the same codebase, that deviation must be documented. The code comment added:

```swift
/// ## Copyable
///
/// Unlike `Stack.Small<Element>` which is `~Copyable` because it stores
/// potentially move-only elements, `Set<Bit>.Packed.Small` stores only `UInt`
/// words (always trivial) and has no generic element type. Therefore it is
/// unconditionally `Copyable`, enabling `Sequence`, `Equatable`, and `Hashable`.
```

This comment does three things:

1. **Acknowledges the pattern**: "Unlike `Stack.Small`..." signals awareness of the expected pattern.
2. **Explains the difference**: "stores only `UInt` words (always trivial)" gives the concrete reason.
3. **States the consequence**: "enabling `Sequence`, `Equatable`, and `Hashable`" shows the benefit.

### Why Future Readers Need This

Without the comment, a future maintainer might:

1. See `Stack.Small` is `~Copyable`
2. See `Set<Bit>.Packed.Small` is not `~Copyable`
3. Assume the latter is wrong and "fix" it
4. Discover it doesn't compile
5. Spend hours understanding why

The comment short-circuits this: the deviation is intentional, the reason is documented, the investigation is unnecessary.

### The Pattern for Documenting Deviation

```swift
/// ## [Property Name]
///
/// Unlike `[Reference Type]` which [does X] because [reason],
/// `[This Type]` [does Y] because [different reason].
/// Therefore it [has consequence].
```

This template applies whenever a type intentionally differs from a similar type in the same layer.

**Applies to**: All intentional pattern deviations.

---

## The Naming Mirror — Set<Bit>.Packed from Array<Bit>.Packed

**Date**: 2026-01-21

**Context**: Renaming `Bit.Set` to `Set<Bit>.Packed` to mirror `Array<Bit>.Packed`.

### The Naming Principle

The existing naming was:
- `Array<Bit>.Packed` — array of bits packed into words
- `Bit.Set` — set of bits packed into words

The asymmetry is jarring. Both are packed bit containers; their names should reflect this:
- `Array<Bit>.Packed` — packed bit array
- `Set<Bit>.Packed` — packed bit set

The new naming follows [API-NAME-003]: types implementing the same concept for different container semantics should mirror each other's structure.

### The Implementation Pattern

```swift
// Array<Bit>.Packed uses:
extension Array where Element == Bit {
    public struct Packed: Sendable { ... }
}

// Set<Bit>.Packed now uses:
extension Set where Element == Bit {
    public struct Packed: Sendable { ... }
}
```

This works because `Bit: Hashable`, satisfying `Set`'s element requirement. The extension constraint `where Element == Bit` pins the namespace to exactly the bit-set case.

### The Variant Hierarchy Parallel

Both types now have matching variant hierarchies:

| Array<Bit>.Packed | Set<Bit>.Packed | Purpose |
|-------------------|-----------------|---------|
| `.init()` | `.init()` | Dynamic heap-backed |
| `.Inline<N>` | `.Inline<N>` | Fixed inline capacity |
| `.Fixed` | `.Fixed` | Fixed heap capacity |
| — | `.Small<N>` | Inline + heap spill |

The `Small` variant exists for `Set<Bit>.Packed` but not yet for `Array<Bit>.Packed`. This is intentional: bit sets commonly need small-buffer optimization (tracking a handful of flags), while packed bit arrays are typically used for larger data (images, binary data).

**Applies to**: Naming decisions for parallel container types.

---

## The Spill-to-Heap Bug and Defensive State Management

**Date**: 2026-01-21

**Context**: Fixing a data-loss bug in `Set<Bit>.Packed.Small._spillToHeap` that occurred when growing already-spilled storage.

### The Bug Pattern

The initial implementation had a subtle state management bug:

```swift
// BROKEN
mutating func _spillToHeap(toInclude bitIndex: Int) {
    let requiredWords = (bitIndex / Self._bitsPerWord) + 1
    var heap = ContiguousArray<UInt>(repeating: 0, count: requiredWords)
    for i in 0..<inlineWordCount {
        heap[i] = _inlineStorage[i]  // Wrong when already spilled!
    }
    _heapStorage = heap
}
```

When called after already spilling, this code:
1. Creates new heap storage
2. Copies from `_inlineStorage` (which is stale after first spill)
3. Discards existing `_heapStorage` (which contained the actual data)

The bug manifested only on the *second* spill—the first spill worked correctly. Tests inserting a single value beyond inline capacity passed. Tests inserting two values beyond inline capacity lost the first value.

### The Fix: Branch on Current State

```swift
// CORRECT
mutating func _spillToHeap(toInclude bitIndex: Int) {
    let requiredWords = (bitIndex / Self._bitsPerWord) + 1

    if var existingHeap = _heapStorage {
        // Growing existing heap
        existingHeap.append(contentsOf: repeatElement(0 as UInt, count: requiredWords - existingHeap.count))
        _heapStorage = existingHeap
    } else {
        // First spill from inline
        var heap = ContiguousArray<UInt>(repeating: 0, count: requiredWords)
        for i in 0..<inlineWordCount {
            heap[i] = _inlineStorage[i]
        }
        _heapStorage = heap
    }
    _capacity = requiredWords * Self._bitsPerWord
}
```

The method now checks which storage mode is active and handles each case correctly.

### The Defensive Programming Principle

State-dependent operations must explicitly handle all states. The bug occurred because the original code *assumed* it was always in inline mode. The fix *checks* which mode is active.

For small-buffer-optimization types with dual storage:
1. Every mutating operation should know which storage is active
2. Transitions between modes must preserve data from the *current* mode
3. Tests must exercise sequences that cross modes multiple times

**Applies to**: All small-buffer-optimization types with dual storage.

---

## Clear vs RemoveAll — Semantic Distinction in Small Variants

**Date**: 2026-01-21

**Context**: Designing the API for resetting `Set<Bit>.Packed.Small` to empty state.

### The Two Operations

```swift
/// Removes all bits and returns to inline storage mode.
public mutating func clear() {
    _inlineStorage = .init(repeating: 0)
    _heapStorage = nil
    _capacity = Self.inlineCapacity
}

/// Removes all bits but keeps current storage mode.
public mutating func removeAll() {
    if _heapStorage != nil {
        for i in _heapStorage!.indices {
            _heapStorage![i] = 0
        }
    } else {
        _inlineStorage = .init(repeating: 0)
    }
    // _capacity unchanged, _heapStorage retained
}
```

### Why Both Are Needed

**`clear()`** is for "reset to initial state":
- User finished with current data
- Next use case may be small (likely fits inline)
- Deallocating heap storage is desirable

**`removeAll()`** is for "empty but reuse":
- Batch processing multiple datasets
- Each dataset likely similar size
- Avoiding repeated spill/deallocate cycles

The distinction mirrors `Array.removeAll(keepingCapacity:)` but split into two methods for clarity. The small-buffer optimization makes the distinction more significant: `clear()` actually changes the storage mode, not just the count.

### The Naming Convention

Both are single-word methods per [API-NAME-002]. The names communicate:
- `clear`: thorough, complete reset (returns to initial state)
- `removeAll`: removes elements, might preserve structure

This semantic distinction should be consistent across small-variant types. `Stack.Small`, `Queue.Small`, `Set.Ordered.Small` should follow the same pattern if they have similar storage modes.

**Applies to**: All small-variant types with dual storage.

---

## Related

- Set
