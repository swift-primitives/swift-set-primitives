# Audit: swift-set-primitives

## Legacy — Consolidated 2026-04-08

### From: swift-institute/Research/audit-primitives.md (2026-04-03)

**Pre-publication dependency-tree audit — P0/P1/P2 checks**

#### P1: Multi-Type File [API-IMPL-005]

**File**: `Sources/Set Primitives Core/Set.Ordered.Error.swift` (3 types, 170 lines)

| Line | Type |
|------|------|
| 22 | `__SetOrderedError<Element>` |
| 58 | `__SetOrderedFixedError<Element>` |
| 118 | `__SetOrderedInlineError<Element>` |

Plus nested `InvalidCapacity` structs within each (line 96).

**Assessment**: `__`-prefixed internal error enums hoisted to module scope for typed throws. Grouping is justified: related error types for variants of the same data structure sharing documentation context.

**Recommendation**: Accept as-is. The `__` prefix signals implementation infrastructure, not public API surface.

---

### From: swift-institute/Research/audits/implementation-naming-2026-03-20/swift-set-primitives.md (2026-03-20)

**Implementation + naming audit**

HIGH=0, MEDIUM=6, LOW=17, INFO=10
Finding IDs: IMPL-002, IMPL-010, IMPL-020, IMPL-050, PATTERN-017, PATTERN-021, SET-001, SET-002, SET-003, SET-004, SET-005, SET-006, SET-007, SET-008, SET-009 (+14 more)
