---
name: set-primitives
description: |
  Set collection primitives with ~Copyable element support.
  ALWAYS apply when working with set/hash table data structures.

layer: implementation

requires:
  - primitives
  - memory

applies_to:
  - swift
  - swift-primitives
  - swift-set-primitives
---

# Set Primitives

Hash set collection with ~Copyable element support.

---

## Core Design Decisions

### [SET-001] Noncopyable Hashable Architecture

**Statement**: Sets MUST support `~Copyable` elements that are `Hashable`.

Key insight: `Hashable` does not require `Copyable`. Elements can be hashed via borrowing.

### [SET-002] Storage Architecture

Uses ManagedBuffer for heap storage with cached pointer for span access.

---

## Cross-References

Full analysis: `Research/Noncopyable Hashable Architecture.md`
