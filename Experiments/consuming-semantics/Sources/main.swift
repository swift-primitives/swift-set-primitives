// MARK: - Consuming Semantics Investigation
// Purpose: Determine if Swift's ownership modifiers can replace naming conventions
//
// Toolchain: Apple Swift version 6.2.3
// Date: 2026-01-22
//
// ============================================================================
// FINDINGS SUMMARY
// ============================================================================
//
// [Q1] Can we overload methods by ownership modifier (borrowing vs consuming)?
//      ANSWER: NO - "invalid redeclaration" error
//
// [Q2] Can consuming func forEach coexist with borrowing func forEach?
//      ANSWER: NO - Same signature, different ownership = redeclaration error
//
// [Q3] Does the compiler disambiguate based on call-site context?
//      ANSWER: NO - Reports "ambiguous use" even with different return types
//
// [Q4] Can closure parameter ownership disambiguate?
//      ANSWER: NO - (borrowing Element) vs (consuming Element) = ambiguous
//
// [Q5] What about property vs consuming method with same name?
//      ANSWER: NO - "invalid redeclaration" error
//
// [Q6] Can ~Copyable types conform to Sequence?
//      ANSWER: NO - Sequence requires Copyable conformance
//
// CONCLUSION: The naming convention (consumingForEach, makeConsumingIterator)
// is REQUIRED. Swift 6.2 does not support ownership-based overloading.
//
// ============================================================================

// MARK: - What DOES Work

// 1. Different names for different ownership semantics
struct Container1<Element: Hashable>: ~Copyable {
    var elements: [Element]

    init(_ elements: [Element]) {
        self.elements = elements
    }

    // Borrowing version - standard name
    borrowing func forEach(_ body: (borrowing Element) throws -> Void) rethrows {
        for element in elements {
            try body(element)
        }
    }

    // Consuming version - MUST use different name
    consuming func consumingForEach(_ body: (consuming Element) -> Void) {
        for element in elements {
            body(element)
        }
    }
}

func test1() {
    print("--- Test 1: Different Names Required ---")

    var container = Container1([1, 2, 3])

    // Borrowing - container remains valid
    container.forEach { element in
        print("Borrowed: \(element)")
    }
    print("Container still valid: \(container.elements.count) elements")

    // Consuming - container is consumed
    container.consumingForEach { element in
        print("Consumed: \(element)")
    }
    // container is now invalid

    print()
}

// MARK: - 2. Iterator Pattern - Different Names Required

struct Container2<Element: Hashable>: ~Copyable {
    var elements: [Element]

    init(_ elements: [Element]) {
        self.elements = elements
    }

    // Standard iterator (Copyable, borrowing)
    struct Iterator: IteratorProtocol {
        var elements: [Element]
        var index: Int = 0

        mutating func next() -> Element? {
            guard index < elements.count else { return nil }
            defer { index += 1 }
            return elements[index]
        }
    }

    // Consuming iterator (~Copyable)
    struct ConsumingIterator: ~Copyable {
        var elements: [Element]
        var index: Int = 0

        mutating func next() -> Element? {
            guard index < elements.count else { return nil }
            defer { index += 1 }
            return elements[index]
        }
    }

    // Standard name for borrowing
    borrowing func makeIterator() -> Iterator {
        Iterator(elements: elements)
    }

    // Different name REQUIRED for consuming
    consuming func makeConsumingIterator() -> ConsumingIterator {
        ConsumingIterator(elements: elements)
    }
}

func test2() {
    print("--- Test 2: Iterator Pattern ---")

    var container = Container2(["a", "b", "c"])

    // Borrowing iterator
    var iter1 = container.makeIterator()
    while let element = iter1.next() {
        print("Borrowed: \(element)")
    }
    print("Container still valid")

    // Consuming iterator
    var iter2 = container.makeConsumingIterator()
    while let element = iter2.next() {
        print("Consumed: \(element)")
    }
    // container is now invalid

    print()
}

// MARK: - 3. The `consume` Operator - Doesn't Help with Overloading

struct Container3<Element: Hashable>: ~Copyable {
    var elements: [Element]

    init(_ elements: [Element]) {
        self.elements = elements
    }

    // Only ONE method - no overloading possible
    // The `consume` operator transfers ownership but doesn't select overloads
    consuming func process() -> [Element] {
        elements
    }
}

func test3() {
    print("--- Test 3: consume Operator ---")

    let container = Container3([1, 2, 3])

    // `consume` transfers ownership to the call
    let result = (consume container).process()
    print("Processed: \(result)")

    // The `consume` operator is for EXPLICIT ownership transfer,
    // not for selecting between overloaded methods

    print()
}

// MARK: - 4. Namespace Pattern - Partial Alternative

// The namespace accessor pattern has limitations with ~Copyable:
// - A property getter borrows self, cannot consume
// - Need a consuming method instead

struct Container4<Element: Hashable>: ~Copyable {
    var elements: [Element]

    init(_ elements: [Element]) {
        self.elements = elements
    }

    // Standard borrowing forEach
    borrowing func forEach(_ body: (borrowing Element) throws -> Void) rethrows {
        for element in elements {
            try body(element)
        }
    }

    // Consuming namespace - MUST be a method, not property
    // Because property getters borrow self
    consuming func consuming() -> ConsumingAccessor {
        ConsumingAccessor(container: self)
    }

    struct ConsumingAccessor: ~Copyable {
        var container: Container4

        consuming func forEach(_ body: (consuming Element) -> Void) {
            for element in container.elements {
                body(element)
            }
        }

        consuming func makeIterator() -> ConsumingIterator {
            ConsumingIterator(elements: container.elements)
        }
    }

    struct ConsumingIterator: ~Copyable {
        var elements: [Element]
        var index: Int = 0

        mutating func next() -> Element? {
            guard index < elements.count else { return nil }
            defer { index += 1 }
            return elements[index]
        }
    }
}

func test4() {
    print("--- Test 4: Namespace Accessor Pattern ---")

    let container = Container4([10, 20, 30])

    // Borrowing - direct call
    container.forEach { element in
        print("Borrowed: \(element)")
    }
    print("Container still valid")

    // Consuming - via namespace accessor (must be method call)
    // Reads as: container.consuming().forEach
    // Less elegant than container.consuming.forEach
    container.consuming().forEach { element in
        print("Consumed via accessor: \(element)")
    }

    print("Note: consuming() must be a method, not property, for ~Copyable")
    print()
}

// MARK: - 5. What About Sequence Conformance?

// FINDING: ~Copyable types CANNOT conform to Sequence in Swift 6.2
// Sequence requires Copyable conformance.
//
// This means:
// - for-in loops don't work with ~Copyable containers
// - Must use while-let with explicit iterator
// - makeIterator() name is available for consuming iterator on ~Copyable types

struct Container5<Element: Hashable>: ~Copyable {
    var elements: [Element]

    init(_ elements: [Element]) {
        self.elements = elements
    }

    // Since ~Copyable can't conform to Sequence, we CAN use makeIterator
    // for the consuming version without conflict!
    struct Iterator: ~Copyable {
        var elements: [Element]
        var index: Int = 0

        mutating func next() -> Element? {
            guard index < elements.count else { return nil }
            defer { index += 1 }
            return elements[index]
        }
    }

    // This is now the ONLY makeIterator - no conflict
    consuming func makeIterator() -> Iterator {
        Iterator(elements: elements)
    }
}

func test5() {
    print("--- Test 5: ~Copyable and Sequence ---")

    let container = Container5(["x", "y", "z"])

    // for-in does NOT work with ~Copyable (can't conform to Sequence)
    // for element in container { } // ERROR: does not conform to Sequence

    // Must use while-let pattern
    var iter = container.makeIterator()
    while let element = iter.next() {
        print("Via iterator: \(element)")
    }

    print("Note: Since ~Copyable can't use Sequence, makeIterator() is available")
    print("for consuming semantics without needing 'makeConsumingIterator' name")
    print()
}

// MARK: - Summary

func printSummary() {
    print("""
    === SUMMARY ===

    Swift 6.2 does NOT support overloading by ownership modifier.
    The following are NOT valid:

    ❌ borrowing func foo() + consuming func foo()
    ❌ func bar((borrowing T) -> Void) + func bar((consuming T) -> Void)
    ❌ var count: Int + consuming func count() -> Int

    Additional constraint:
    ❌ ~Copyable types cannot conform to Sequence (requires Copyable)

    For COPYABLE types (Set.Ordered, Set.Ordered.Bounded):
    - Must use naming convention since both borrowing AND consuming needed
    ✅ forEach() vs consumingForEach()
    ✅ makeIterator() vs makeConsumingIterator()
    ✅ count property vs consumingCount() method

    For ~COPYABLE types (Set.Ordered.Inline, Set.Ordered.Small):
    - Cannot conform to Sequence anyway
    - Could theoretically use just makeIterator() for consuming
    - BUT for consistency, still use makeConsumingIterator()

    Alternative: Namespace accessor pattern
    ✅ container.forEach { ... }           // borrowing
    ✅ container.consuming.forEach { ... } // consuming

    RECOMMENDATION:
    The current API design in Set.Ordered is CORRECT.
    The naming convention (consumingForEach, makeConsumingIterator) is
    REQUIRED by Swift's language constraints for Copyable types and
    provides consistency across all variants.
    """)
}

// MARK: - Run Tests

print("=== Consuming Semantics Investigation ===\n")

test1()
test2()
test3()
test4()
test5()

printSummary()
