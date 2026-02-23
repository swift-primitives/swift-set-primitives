# Set Operations Audit

<!--
---
version: 1.0.0
last_updated: 2026-02-16
status: RECOMMENDATION
tier: 1
---
-->

## Context

Proactive audit of swift-set-primitives to inventory all public operations and compare against canonical Set ADT operations.

**Trigger**: [RES-012] Discovery — proactive operations audit across 13 data structure packages.
**Scope**: Package-specific (swift-set-primitives).

## Question

Does swift-set-primitives provide the canonical operations expected of the Set ADT (Ordered Set variant)?

## Canonical Operations (ADT Reference)

### Ordered Set (Insertion-Order-Preserving, Hash-Backed)

| Operation | Expected Complexity | Description |
|-----------|-------------------|-------------|
| add(x) / insert(x) | O(1) avg | Add element (uniqueness enforced) |
| remove(x) | O(1) avg lookup + O(n) shift | Remove element |
| contains(x) | O(1) avg | Membership test |
| iterate | O(n) | Visit all elements in insertion order |
| count / size | O(1) | Number of elements |
| isEmpty | O(1) | Empty check |
| first / last | O(1) | Insertion-order endpoints |
| index(x) | O(1) avg | Position lookup |
| element(at: i) | O(1) | Positional access |

### Set Algebra

| Operation | Expected Complexity | Description |
|-----------|-------------------|-------------|
| union | O(n + m) | A ∪ B |
| intersection | O(n) | A ∩ B |
| difference | O(n) | A \ B |
| symmetric_difference | O(n + m) | A △ B |
| isSubset | O(n) | A ⊆ B |
| isSuperset | O(m) | A ⊇ B |
| isDisjoint | O(min(n,m)) | A ∩ B = ∅ |

---

## Current Operations Inventory

### Variant: Set.Ordered (Dynamic, Heap-Allocated)

#### Core Operations (Copyable elements)

| Canonical Operation | Method / Property | Signature | Complexity | Source File |
|---------------------|-------------------|-----------|------------|-------------|
| insert | `insert(_:)` | `mutating func insert(_ element: Element) -> (inserted: Bool, index: Index<Element>)` | O(1) avg | `Set.Ordered Copyable.swift:77` |
| remove | `remove(_:)` | `mutating func remove(_ element: Element) -> Element?` | O(1) lookup + O(n) shift | `Set.Ordered Copyable.swift:96` |
| contains | `contains(_:)` | `func contains(_ element: Element) -> Bool` | O(1) avg | `Set.Ordered Copyable.swift:114` |
| index | `index(_:)` | `func index(_ element: Element) -> Index<Element>?` | O(1) avg | `Set.Ordered Copyable.swift:67` |
| element(at:) | `element(at:)` | `func element(at index: Index<Element>) throws(__SetOrderedError<Element>) -> Element` | O(1) | `Set.Ordered Copyable.swift:137` |
| subscript | `subscript` | `subscript(index: Index<Element>) -> Element` | O(1) | `Set.Ordered Copyable.swift:146` |
| count | `count` | `var count: Index<Element>.Count` | O(1) | `Set.Ordered ~Copyable.swift:24` |
| isEmpty | `isEmpty` | `var isEmpty: Bool` | O(1) | `Set.Ordered ~Copyable.swift:28` |
| capacity | `capacity` | `var capacity: Index<Element>.Count` | O(1) | `Set.Ordered ~Copyable.swift:32` |
| first | `first` | `var first: Element?` | O(1) | `Set.Ordered Copyable.swift:159` |
| last | `last` | `var last: Element?` | O(1) | `Set.Ordered Copyable.swift:165` |
| clear | `clear(keepingCapacity:)` | `mutating func clear(keepingCapacity: Bool = false)` | O(n) | `Set.Ordered Copyable.swift:123` |
| removeAll | `removeAll()` | `mutating func removeAll()` | O(n) | `Set.Ordered Copyable.swift:308` |
| reserve | `reserve(_:)` | `mutating func reserve(_ minimumCapacity: Index<Element>.Count)` | O(n) amortized | `Set.Ordered ~Copyable.swift:42` |

#### ~Copyable-Compatible Operations (all elements)

| Operation | Method / Property | Signature | Source File |
|-----------|-------------------|-----------|-------------|
| withElement | `withElement(at:_:)` | `func withElement<R>(at index: Index<Element>, _ body: (borrowing Element) -> R) -> R` | `Set.Ordered ~Copyable.swift:60` |
| withElement (throwing) | `withElement(at:_:)` | `func withElement<R>(at:, _ body: (borrowing Element) throws(__SetOrderedError<Element>) -> R) throws -> R` | `Set.Ordered ~Copyable.swift:73` |
| forEach | `forEach(_:)` | `func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)` | `Set.Ordered ~Copyable.swift:84` |
| withSpan | `withSpan(_:)` | `func withSpan<R, E: Swift.Error>(_ body: (Span<Element>) throws(E) -> R) throws(E) -> R` | `Set.Ordered ~Copyable.swift:107` |

#### Iteration & Consumption

| Operation | Method / Property | Signature | Constraint | Source File |
|-----------|-------------------|-----------|------------|-------------|
| makeIterator | `makeIterator()` | `borrowing func makeIterator() -> Iterator` | `Element: Copyable` | `Set.Ordered.Iterator.swift:56` |
| drain (method) | `drain(_:)` | `mutating func drain(_ body: (consuming Element) -> Void)` | `Element: Copyable` | `Set.Ordered Copyable.swift:179` |
| drain (accessor) | `drain` | `var drain: Property<Sequence.Drain, Self>.View` | all elements | `Set.Ordered+Sequence.Drain.swift:39` |
| consume | `consume()` | `consuming func consume() -> Sequence.Consume.View<...>` | `Element: Copyable` | `Set.Ordered+Sequence.Consume.swift:43` |

#### Memory Access (behind `@_spi(Unsafe)`)

| Operation | Method / Property | Constraint | Source File |
|-----------|-------------------|------------|-------------|
| withUnsafeBufferPointer | `withUnsafeBufferPointer(_:)` | all elements | `Set.Ordered ~Copyable.swift:123` |
| withUnsafeMutableBufferPointer | `withUnsafeMutableBufferPointer(_:)` | `Element: Copyable` | `Set.Ordered Copyable.swift:217` |
| withMutableSpan | `withMutableSpan(_:)` | `Element: Copyable` | `Set.Ordered Copyable.swift:199` |

#### Protocol Conformances

| Protocol | Constraint | Source File |
|----------|------------|-------------|
| `Copyable` | `where Element: Copyable` | `Set.swift:182` |
| `@unchecked Sendable` | `where Element: Sendable` | `Set.swift:187` |
| `Hash.Protocol` (Equatable + Hashable) | unconditional | `Set.Ordered Copyable.swift:230` |
| `Swift.Sequence` | `where Element: Copyable` | `Set.Ordered.Iterator.swift:69` |
| `Sequence.Protocol` | `where Element: Copyable` | `Set.Ordered Copyable.swift:290` |
| `Sequence.Clearable` | `where Element: Copyable` | `Set.Ordered Copyable.swift:303` |
| `Sequence.Drain.Protocol` | unconditional | `Set.Ordered+Sequence.Drain.swift:18` |

#### Initializers

| Initializer | Signature | Constraint | Source File |
|-------------|-----------|------------|-------------|
| Empty | `init()` | all elements | `Set.swift:61` |
| Reserving | `init(reservingCapacity:)` | all elements | `Set.Ordered Copyable.swift:24` |
| From sequence | `init<S: Swift.Sequence>(_ elements: S)` | `Element: Copyable` | `Set.Ordered Copyable.swift:35` |

#### Other

| Operation | Method / Property | Source File |
|-----------|-------------------|-------------|
| description | `var description: String` | `Set.Ordered Copyable.swift:269` |
| underestimatedCount | `var underestimatedCount: Int` | `Set.Ordered Copyable.swift:296` |

---

### Variant: Set.Ordered.Fixed (Fixed-Capacity, Heap-Allocated)

#### Core Operations (Copyable elements)

| Canonical Operation | Method / Property | Signature | Complexity | Source File |
|---------------------|-------------------|-----------|------------|-------------|
| insert | `insert(_:)` | `mutating func insert(_ element: Element) throws(__SetOrderedFixedError<Element>) -> (inserted: Bool, index: Index<Element>)` | O(1) avg | `Set.Ordered.Fixed.swift:71` |
| remove | `remove(_:)` | `mutating func remove(_ element: Element) -> Element?` | O(1) lookup + O(n) shift | `Set.Ordered.Fixed.swift:97` |
| contains | `contains(_:)` | `func contains(_ element: Element) -> Bool` | O(1) avg | `Set.Ordered.Fixed.swift:115` |
| index | `index(_:)` | `func index(_ element: Element) -> Index<Element>?` | O(1) avg | `Set.Ordered.Fixed.swift:57` |
| element(at:) | `element(at:)` | `func element(at index: Index<Element>) throws(__SetOrderedFixedError<Element>) -> Element` | O(1) | `Set.Ordered.Fixed.swift:136` |
| subscript | `subscript` | `subscript(index: Index<Element>) -> Element` | O(1) | `Set.Ordered.Fixed.swift:145` |
| count | `count` | `var count: Index<Element>.Count` | O(1) | `Set.Ordered.Fixed.swift:25` |
| isEmpty | `isEmpty` | `var isEmpty: Bool` | O(1) | `Set.Ordered.Fixed.swift:29` |
| isFull | `isFull` | `var isFull: Bool` | O(1) | `Set.Ordered.Fixed.swift:33` |
| capacity | `capacity` | `var capacity: Index<Element>.Count` | O(1) | `Set.Ordered.Fixed.swift:37` |
| first | `first` | `var first: Element?` | O(1) | `Set.Ordered.Fixed.swift:156` |
| last | `last` | `var last: Element?` | O(1) | `Set.Ordered.Fixed.swift:162` |
| clear | `clear(keepingCapacity:)` | `mutating func clear(keepingCapacity: Bool = false)` | O(n) | `Set.Ordered.Fixed.swift:124` |
| removeAll | `removeAll()` | `mutating func removeAll()` | O(n) | `Set.Ordered.Fixed Copyable.swift:87` |

#### ~Copyable-Compatible Operations (all elements)

| Operation | Method / Property | Source File |
|-----------|-------------------|-------------|
| withElement | `withElement(at:_:)` (precondition) | `Set.Ordered.Fixed.swift:174` |
| withElement (throwing) | `withElement(at:_:)` (typed throws) | `Set.Ordered.Fixed.swift:181` |
| forEach | `forEach<E>(_:)` (borrowing) | `Set.Ordered.Fixed.swift:190` |
| drain (method) | `drain(_:)` (consuming) | `Set.Ordered.Fixed.swift:203` |
| drain (accessor) | `var drain: Property<...>.View` | `Set.Ordered.Fixed+Sequence.Drain.swift:35` |
| withSpan | `withSpan(_:)` | `Set.Ordered.Fixed.swift:217` |
| withMutableSpan | `withMutableSpan(_:)` (Copyable) | `Set.Ordered.Fixed.swift:228` |

#### Iteration & Consumption

| Operation | Constraint | Source File |
|-----------|------------|-------------|
| `makeIterator()` | `Element: Copyable` | `Set.Ordered.Fixed Copyable.swift:61` |
| `consume()` | `Element: Copyable` | `Set.Ordered.Fixed+Sequence.Consume.swift:33` |

#### Protocol Conformances

| Protocol | Constraint | Source File |
|----------|------------|-------------|
| `Copyable` | `where Element: Copyable` | `Set.swift:183` |
| `@unchecked Sendable` | `where Element: Sendable` | `Set.swift:188` |
| `Hash.Protocol` | unconditional | `Set.Ordered.Fixed.swift:265` |
| `Swift.Sequence` | `where Element: Copyable` | `Set.Ordered.Fixed Copyable.swift:56` |
| `Sequence.Protocol` | `where Element: Copyable` | `Set.Ordered.Fixed Copyable.swift:70` |
| `Sequence.Clearable` | `where Element: Copyable` | `Set.Ordered.Fixed Copyable.swift:80` |
| `Sequence.Drain.Protocol` | unconditional | `Set.Ordered.Fixed+Sequence.Drain.swift:18` |

#### Memory Access (behind `@_spi(Unsafe)`)

| Operation | Constraint | Source File |
|-----------|------------|-------------|
| `withUnsafeBufferPointer(_:)` | all elements | `Set.Ordered.Fixed.swift:244` |
| `withUnsafeMutableBufferPointer(_:)` | `Element: Copyable` | `Set.Ordered.Fixed.swift:254` |

#### Initializer

| Initializer | Signature | Source File |
|-------------|-----------|-------------|
| Capacity | `init(capacity: Index<Element>.Count) throws(__SetOrderedFixedError<Element>)` | `Set.swift:87` |

---

### Variant: Set.Ordered.Static<capacity> (Inline Storage, Compile-Time Capacity)

#### Core Operations (all elements — no Copyable constraint required)

| Canonical Operation | Method / Property | Signature | Complexity | Source File |
|---------------------|-------------------|-----------|------------|-------------|
| insert | `insert(_:)` | `mutating func insert(_ element: Element) throws(__SetOrderedInlineError<Element>) -> (inserted: Bool, index: Index<Element>.Bounded<capacity>)` | O(1) avg | `Set.Ordered.Static.swift:84` |
| remove | `remove(_:)` | `mutating func remove(_ element: Element) -> Element?` | O(1) lookup + O(n) shift | `Set.Ordered.Static.swift:114` |
| contains | `contains(_:)` | `mutating func contains(_ element: Element) -> Bool` | O(1) avg | `Set.Ordered.Static.swift:69` |
| index | `index(_:)` | `mutating func index(_ element: Element) -> Index<Element>.Bounded<capacity>?` | O(1) avg | `Set.Ordered.Static.swift:55` |
| element(at:) (Index) | `element(at:)` | `func element(at index: Index<Element>) throws(__SetOrderedInlineError<Element>) -> Element` | O(1) | `Set.Ordered.Static.swift:147` |
| element(at:) (Bounded) | `element(at:)` | `func element(at index: Index<Element>.Bounded<capacity>) throws -> Element` | O(1) | `Set.Ordered.Static.swift:160` |
| subscript (Index) | `subscript` | `subscript(index: Index<Element>) -> Element` | O(1) | `Set.Ordered.Static.swift:170` |
| subscript (Bounded) | `subscript` | `subscript(index: Index<Element>.Bounded<capacity>) -> Element` | O(1) | `Set.Ordered.Static.swift:181` |
| count | `count` | `var count: Index<Element>.Count` | O(1) | `Set.Ordered.Static.swift:35` |
| isEmpty | `isEmpty` | `var isEmpty: Bool` | O(1) | `Set.Ordered.Static.swift:39` |
| isFull | `isFull` | `var isFull: Bool` | O(1) | `Set.Ordered.Static.swift:43` |
| first | `first` | `var first: Element?` | O(1) | `Set.Ordered.Static.swift:192` |
| last | `last` | `var last: Element?` | O(1) | `Set.Ordered.Static.swift:198` |
| clear | `clear()` | `mutating func clear()` | O(n) | `Set.Ordered.Static.swift:135` |
| removeAll | `removeAll()` | `mutating func removeAll()` | O(n) | `Set.Ordered.Static Copyable.swift:97` |

**Notable**: `contains(_:)` and `index(_:)` are `mutating` on `Static` (compiler limitation with `Hash.Table.Static` which uses inline storage).

#### ~Copyable-Compatible Operations (all elements)

| Operation | Method / Property | Source File |
|-----------|-------------------|-------------|
| withElement (Index) | `withElement(at:_:)` | `Set.Ordered.Static.swift:210` |
| withElement (Bounded) | `withElement(at:_:)` | `Set.Ordered.Static.swift:217` |
| forEach | `forEach<E>(_:)` | `Set.Ordered.Static.swift:224` |
| drain (method) | `drain(_:)` | `Set.Ordered.Static.swift:237` |
| drain (accessor) | `var drain: Property<...>.View` | `Set.Ordered.Static+Sequence.Drain.swift:35` |

#### Iteration & Consumption

| Operation | Constraint | Source File |
|-----------|------------|-------------|
| `makeIterator()` (snapshot copy) | `Element: Copyable` | `Set.Ordered.Static Copyable.swift:72` |
| `consume()` | all elements | `Set.Ordered.Static+Sequence.Consume.swift:34` |

#### Protocol Conformances

| Protocol | Constraint | Source File |
|----------|------------|-------------|
| `~Copyable` (unconditionally) | — | `Set.swift:106` |
| `@unchecked Sendable` | `where Element: Sendable` | `Set.swift:189` |
| `Sequence.Protocol` | `where Element: Copyable` | `Set.Ordered.Static Copyable.swift:62` |
| `Sequence.Clearable` | `where Element: Copyable` | `Set.Ordered.Static Copyable.swift:92` |
| `Sequence.Drain.Protocol` | unconditional | `Set.Ordered.Static+Sequence.Drain.swift:18` |

**Notable**: `Static` does NOT conform to `Swift.Sequence` (unconditionally `~Copyable`, cannot satisfy `Sequence`'s `Copyable` requirement on `Self`). It does NOT conform to `Hash.Protocol` (no `==` or `hash(into:)` implementation).

---

### Variant: Set.Ordered.Small<inlineCapacity> (SmallVec Pattern)

#### Core Operations (Copyable elements)

| Canonical Operation | Method / Property | Signature | Complexity | Source File |
|---------------------|-------------------|-----------|------------|-------------|
| insert | `insert(_:)` | `mutating func insert(_ element: Element) -> (inserted: Bool, index: Index<Element>)` | O(n) inline / O(1) avg heap | `Set.Ordered.Small.swift:87` |
| remove | `remove(_:)` | `mutating func remove(_ element: Element) -> Element?` | O(n) inline / O(1)+O(n) heap | `Set.Ordered.Small.swift:108` |
| contains | `contains(_:)` | `mutating func contains(_ element: Element) -> Bool` | O(n) inline / O(1) avg heap | `Set.Ordered.Small.swift:78` |
| index | `index(_:)` | `mutating func index(_ element: Element) -> Index<Element>?` | O(n) inline / O(1) avg heap | `Set.Ordered.Small.swift:59` |
| element(at:) (optional) | `element(at:)` | `func element(at index: Index<Element>) -> Element?` | O(1) | `Set.Ordered.Small.swift:179` |
| element(at:) (throwing) | `element(at:)` | `func element(at index: Index<Element>) throws(__SetOrderedError<Element>) -> Element` | O(1) | `Set.Ordered.Small.swift:186` |
| subscript | `subscript` | `subscript(index: Index<Element>) -> Element` | O(1) | `Set.Ordered.Small.swift:195` |
| count | `count` | `var count: Index<Element>.Count` | O(1) | `Set.Ordered.Small.swift:37` |
| isEmpty | `isEmpty` | `var isEmpty: Bool` | O(1) | `Set.Ordered.Small.swift:43` |
| capacity | `capacity` | `var capacity: Index<Element>.Count` | O(1) | `Set.Ordered.Small.swift:47` |
| isSpilled | `isSpilled` | `var isSpilled: Bool` | O(1) | `Set.swift:175` |
| first | `first` | `var first: Element?` | O(1) | `Set.Ordered.Small.swift:208` |
| last | `last` | `var last: Element?` | O(1) | `Set.Ordered.Small.swift:215` |
| clear | `clear(keepingCapacity:)` | `mutating func clear(keepingCapacity: Bool = false)` | O(n) | `Set.Ordered.Small.swift:135` |
| removeAll | `removeAll()` | `mutating func removeAll()` | O(n) | `Set.Ordered.Small Copyable.swift:98` |

#### ~Copyable-Compatible Operations (all elements)

| Operation | Method / Property | Source File |
|-----------|-------------------|-------------|
| withElement | `withElement(at:_:)` | `Set.Ordered.Small.swift:229` |
| withElement (throwing) | `withElement(at:_:)` (typed throws) | `Set.Ordered.Small.swift:236` |
| forEach | `forEach<E>(_:)` | `Set.Ordered.Small.swift:245` |
| drain (method) | `drain(_:)` | `Set.Ordered.Small.swift:258` |
| drain (accessor) | `var drain: Property<...>.View` | `Set.Ordered.Small+Sequence.Drain.swift:35` |
| withSpan | `withSpan(_:)` | `Set.Ordered.Small.swift:288` |
| withMutableSpan | `withMutableSpan(_:)` | `Set.Ordered.Small.swift:299` |

#### Iteration & Consumption

| Operation | Constraint | Source File |
|-----------|------------|-------------|
| `makeIterator()` (snapshot copy) | `Element: Copyable` | `Set.Ordered.Small Copyable.swift:72` |
| `consume()` | `Element: Copyable` | `Set.Ordered.Small+Sequence.Consume.swift:36` |

#### Protocol Conformances

| Protocol | Constraint | Source File |
|----------|------------|-------------|
| `~Copyable` (unconditionally) | — | `Set.swift:146` |
| `@unchecked Sendable` | `where Element: Sendable` | `Set.swift:190` |
| `Sequence.Protocol` | `where Element: Copyable` | `Set.Ordered.Small Copyable.swift:62` |
| `Sequence.Clearable` | `where Element: Copyable` | `Set.Ordered.Small Copyable.swift:92` |
| `Sequence.Drain.Protocol` | unconditional | `Set.Ordered.Small+Sequence.Drain.swift:18` |

**Notable**: `Small` does NOT conform to `Swift.Sequence` (same reason as `Static`). Does NOT conform to `Hash.Protocol`.

#### Memory Access (behind `@_spi(Unsafe)`)

| Operation | Constraint | Source File |
|-----------|------------|-------------|
| `withUnsafeBufferPointer(_:)` | `Element: Copyable` | `Set.Ordered.Small.swift:318` |
| `withUnsafeMutableBufferPointer(_:)` | `Element: Copyable` | `Set.Ordered.Small.swift:330` |

---

### Set Algebra Operations

All algebra operations exist ONLY on `Set.Ordered` (Copyable elements). They are accessed through the `.algebra` nested accessor pattern.

| Operation | Method | Return Type | Complexity | Source File |
|-----------|--------|-------------|------------|-------------|
| union | `algebra.union(_:)` | `Set<Element>.Ordered` | O(n + m) | `Set.Ordered.Algebra.swift:72` |
| intersection | `algebra.intersection(_:)` | `Set<Element>.Ordered` | O(n) | `Set.Ordered.Algebra.swift:99` |
| difference | `algebra.subtract(_:)` | `Set<Element>.Ordered` | O(n) | `Set.Ordered.Algebra.swift:121` |
| symmetric difference | `algebra.symmetric.difference(_:)` | `Set<Element>.Ordered` | O(n + m) | `Set.Ordered.Algebra.Symmetric.swift:50` |
| mutating form | `form(_:)` | `Void` | depends on operation | `Set.Ordered.Algebra.swift:149` |

### Phantom-Typed Indexed Wrappers

Two indexed wrapper types provide phantom-typed index access. These are separate from the core variants but surface all essential operations.

#### Set.Ordered.Indexed\<Tag\>

| Operation | Source File |
|-----------|-------------|
| `init(_:)`, `count`, `isEmpty`, `capacity` | `Set.Ordered.Indexed.swift` |
| `subscript(Index<Tag>)` | `Set.Ordered.Indexed.swift:85` |
| `contains(_:)`, `index(_:)` | `Set.Ordered.Indexed.swift:114,120` |
| `insert(_:)`, `remove(_:)`, `clear(keepingCapacity:)` | `Set.Ordered.Indexed.swift:135,147,154` |
| `first`, `last` | `Set.Ordered.Indexed.swift:164,168` |

#### Set.Ordered.Fixed.Indexed\<Tag\>

| Operation | Source File |
|-----------|-------------|
| `init(_:)`, `count`, `isEmpty`, `capacity`, `isFull` | `Set.Ordered.Fixed.Indexed.swift` |
| `subscript(Index<Tag>)` | `Set.Ordered.Fixed.Indexed.swift:85` |
| `contains(_:)`, `index(_:)` | `Set.Ordered.Fixed.Indexed.swift:118,124` |
| `insert(_:)`, `remove(_:)`, `clear(keepingCapacity:)` | `Set.Ordered.Fixed.Indexed.swift:140,151,159` |
| `first`, `last` | `Set.Ordered.Fixed.Indexed.swift:169,173` |

---

### Additional Operations (Beyond Canonical)

| Operation | Description | Variants | Source File Pattern |
|-----------|-------------|----------|---------------------|
| `withElement(at:_:)` | Borrowed element access via closure (~Copyable safe) | All 4 | `*~Copyable.swift` / `*.swift` |
| `forEach(_:)` | Borrowing iteration (~Copyable safe) | All 4 | `*~Copyable.swift` / `*.swift` |
| `drain(_:)` | Consuming iteration (set survives, empty) | All 4 | `*.swift` / `*+Sequence.Drain.swift` |
| `drain` (Property.View) | Property accessor for `.drain { }` syntax | All 4 | `*+Sequence.Drain.swift` |
| `consume()` | Consuming view transfer (set consumed) | All 4 | `*+Sequence.Consume.swift` |
| `withSpan(_:)` | Read-only Span access | Ordered, Fixed, Small | `*~Copyable.swift` / `*.swift` |
| `withMutableSpan(_:)` | Mutable Span access (hash invalidation warning) | Ordered, Fixed, Small | `*Copyable.swift` / `*.swift` |
| `withUnsafeBufferPointer(_:)` | Unsafe read access (`@_spi(Unsafe)`) | Ordered, Fixed, Small | Various |
| `withUnsafeMutableBufferPointer(_:)` | Unsafe write access (`@_spi(Unsafe)`) | Ordered, Fixed, Small | Various |
| `isSpilled` | Inline/heap mode query | Small only | `Set.swift:175` |
| `Indexed<Tag>` wrapper | Phantom-typed index access | Ordered, Fixed | `*.Indexed.swift` |
| `description` | String representation | Ordered only | `Set.Ordered Copyable.swift` |
| `init(_ elements: S)` | Sequence-based init with deduplication | Ordered only | `Set.Ordered Copyable.swift` |
| `init(reservingCapacity:)` | Pre-sized init | Ordered only | `Set.Ordered Copyable.swift` |

---

## Gap Analysis

### Present and Correctly Mapped

All four variants provide the core ordered set operations:

| Canonical Operation | Ordered | Fixed | Static | Small |
|---------------------|:-------:|:-----:|:------:|:-----:|
| `insert(_:)` | Yes | Yes (throws overflow) | Yes (throws overflow) | Yes |
| `remove(_:)` | Yes | Yes | Yes | Yes |
| `contains(_:)` | Yes | Yes | Yes | Yes |
| `index(_:)` | Yes | Yes | Yes | Yes |
| `element(at:)` | Yes | Yes | Yes | Yes |
| `subscript` | Yes | Yes | Yes (also Bounded) | Yes |
| `count` | Yes | Yes | Yes | Yes |
| `isEmpty` | Yes | Yes | Yes | Yes |
| `first` | Yes | Yes | Yes | Yes |
| `last` | Yes | Yes | Yes | Yes |
| `clear` | Yes | Yes | Yes | Yes |
| `forEach` (borrowing) | Yes | Yes | Yes | Yes |
| `drain` (consuming) | Yes | Yes | Yes | Yes |
| `consume()` | Yes | Yes | Yes | Yes |
| `makeIterator()` | Yes | Yes | Yes (snapshot) | Yes (snapshot) |

Set algebra operations on `Set.Ordered`:

| Algebra Operation | Present |
|-------------------|:-------:|
| `algebra.union(_:)` | Yes |
| `algebra.intersection(_:)` | Yes |
| `algebra.subtract(_:)` | Yes |
| `algebra.symmetric.difference(_:)` | Yes |
| `form(_:)` (mutating) | Yes |

### Missing — Should Add (Primitives Layer)

These are fundamental set-discipline operations that belong at the primitives layer. Their absence was also identified in the discipline boundary analysis (`set-discipline-boundary-analysis.md`).

| Operation | Description | Priority | Notes |
|-----------|-------------|----------|-------|
| `isSubset(of:)` | A ⊆ B — every element of A is in B | **High** | Present in every major set implementation (Rust, C++, Haskell, Swift stdlib). O(n) using `contains`. |
| `isSuperset(of:)` | A ⊇ B — every element of B is in A | **High** | Trivially `other.isSubset(of: self)`. |
| `isDisjoint(with:)` | A ∩ B = ∅ — no common elements | **High** | O(min(n,m)) using `contains`. |
| `isStrictSubset(of:)` | A ⊂ B — proper subset | **Medium** | `isSubset && count != other.count`. |
| `isStrictSuperset(of:)` | A ⊃ B — proper superset | **Medium** | `isSuperset && count != other.count`. |
| Algebra on `Fixed` / `Static` / `Small` | Set algebra should not be exclusive to the dynamic variant | **Medium** | Return type can be `Set.Ordered` since algebra results have unpredictable size. |
| `Hash.Protocol` on `Static` and `Small` | Equality and hashability for all variants | **Medium** | Currently only `Ordered` and `Fixed` conform. |
| `description` on `Fixed` / `Static` / `Small` | String representation for debugging | **Low** | Currently only `Ordered` has `description`. |

### Missing — Intentionally Absent (Higher Layer)

These operations either require Foundation, higher-layer composition, or have complex semantics that do not belong at the primitives layer.

| Operation | Description | Rationale for Exclusion |
|-----------|-------------|------------------------|
| `filter(_:) -> Set.Ordered` | Filter preserving uniqueness | Can be composed from `forEach` + `insert`. Semantics are straightforward but represent a convenience that belongs at Foundations (Layer 3). |
| `map(_:) -> Set.Ordered` | Transform with uniqueness (may reduce size) | Tricky semantics — output size may differ from input. Better at Foundations. |
| `SetAlgebra` protocol conformance | Swift stdlib protocol | Requires `Equatable` on `Self`, not on elements. Imposes stdlib coupling. |
| `Codable` conformance | Serialization | Requires Foundation. Forbidden at primitives layer [PRIM-FOUND-001]. |
| `ExpressibleByArrayLiteral` | `let set: Set<Int>.Ordered = [1, 2, 3]` | Stdlib protocol conformance. Could be added but low priority. |
| `update(with:)` / replace-or-insert | Idempotent upsert | Convenience — composable from `remove` + `insert`. |
| `popFirst()` / `popLast()` | Remove and return endpoint | Composable from `first` + `remove` or buffer operations. Lower priority than relations. |
| `RangeReplaceableCollection` conformance | Range-based mutation | Complex interaction with uniqueness invariant. Inappropriate for primitives. |
| `min` / `max` | Extrema by `Comparable` | Only meaningful for sorted sets. `Ordered` preserves insertion order, not sort order. `first`/`last` provide insertion-order endpoints. |

---

## Known Issues (Cross-Referenced)

These issues were identified in `set-discipline-boundary-analysis.md` and remain relevant:

| Issue | Severity | Reference |
|-------|----------|-----------|
| `symmetric.difference` is O(n*m) instead of O(n+m) | Medium | `Algebra` struct stores only `Buffer`, not `Hash.Table`, preventing O(1) containment checks. Currently uses linear scan for "check if element is in self". |
| `buffer` and `hashTable` on `Ordered` / `Fixed` are `@usableFromInline package var` (correctly scoped) | Resolved | The discipline analysis flagged the comment `public var` but the actual code uses `package var`. No action needed. |
| Algebra only on `Ordered` | Medium | `Fixed`, `Static`, and `Small` lack algebra. Listed as missing above. |

---

## Variant Feature Matrix (Summary)

| Feature | Ordered | Fixed | Static | Small |
|---------|:-------:|:-----:|:------:|:-----:|
| **Storage** | Heap (dynamic) | Heap (bounded) | Inline | Inline + heap spill |
| **Copyable** | Conditional | Conditional | Never | Never |
| **insert** | `-> (Bool, Index)` | `throws -> (Bool, Index)` | `throws -> (Bool, Bounded)` | `-> (Bool, Index)` |
| **contains/index mutating?** | No | No | Yes (compiler) | Yes (linear scan) |
| **Hash.Protocol conformance** | Yes | Yes | **No** | **No** |
| **Swift.Sequence** | Yes | Yes | **No** | **No** |
| **Set algebra** | Yes | **No** | **No** | **No** |
| **Set relations** | **No** | **No** | **No** | **No** |
| **Indexed\<Tag\>** | Yes | Yes | **No** | **No** |
| **Span access** | Yes | Yes | **No** (strided layout) | Yes |
| **description** | Yes | **No** | **No** | **No** |
| **init from Sequence** | Yes | **No** | **No** | **No** |
| **reserve capacity** | Yes | **No** (fixed) | **No** (fixed) | **No** (auto-spill) |

---

## Outcome

**Status**: RECOMMENDATION

### Summary

`swift-set-primitives` provides a solid and well-structured implementation of the ordered set ADT across four storage variants (Ordered, Fixed, Static, Small). All four variants cover the core point operations (insert, remove, contains, index, element access, count, isEmpty, first/last, clear, iterate, drain, consume). Set algebra operations (union, intersection, difference, symmetric difference) are present on the primary `Ordered` variant.

The most significant gaps are the **set relation operations** (`isSubset`, `isSuperset`, `isDisjoint`) which are absent from ALL variants. These are fundamental set-discipline operations present in every major set implementation and should be added at the primitives layer. The `set-discipline-boundary-analysis.md` research document independently arrived at the same conclusion.

### Priority Ranking

1. **High**: Add `isSubset(of:)`, `isSuperset(of:)`, `isDisjoint(with:)` to `Set.Ordered` (and ideally all variants)
2. **Medium**: Fix `algebra.symmetric.difference` O(n*m) performance to O(n+m)
3. **Medium**: Add `isStrictSubset(of:)`, `isStrictSuperset(of:)` to `Set.Ordered`
4. **Medium**: Extend algebra operations to `Fixed`, `Static`, and `Small` variants (returning `Set.Ordered`)
5. **Medium**: Add `Hash.Protocol` conformance to `Static` and `Small`
6. **Low**: Add `description` to `Fixed`, `Static`, and `Small`
7. **Low**: Add `init(_ elements: S)` to `Fixed` and `Small`
8. **Low**: Add `Indexed<Tag>` wrappers for `Static` and `Small`

---

## References

- `/Users/coen/Developer/swift-primitives/swift-set-primitives/Research/set-discipline-boundary-analysis.md`
- `/Users/coen/Developer/swift-primitives/swift-set-primitives/Research/Noncopyable Hashable Architecture.md`
- `/Users/coen/Developer/swift-primitives/swift-set-primitives/Research/array-set-primitives-comparison.md`
- Liskov & Guttag, "Abstraction and Specification in Program Development": Set ADT axioms
- [Set (abstract data type) — Wikipedia](https://en.wikipedia.org/wiki/Set_(abstract_data_type))
- [Rust `HashSet` — std::collections](https://doc.rust-lang.org/std/collections/struct.HashSet.html)
- [Haskell `Data.Set` — Hackage](https://hackage.haskell.org/package/containers/docs/Data-Set.html)
