public import Buffer_Linear_Primitive
public import Buffer_Primitive
public import Hash_Indexed_Primitive
import Hash_Primitives
import Hash_Table_Primitive
public import Index_Primitives
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
public import Ownership_Shared_Primitive
public import Storage_Contiguous_Primitives
public import Storage_Primitive

@_documentation(visibility: public)
@frozen
public struct __Set<S: ~Copyable>: ~Copyable {

    @usableFromInline
    package var store: S

    @inlinable
    public init(store: consuming S) {
        self.store = store
    }

    @inlinable
    public consuming func take() -> S {
        store
    }
}

extension __Set: Copyable where S: Copyable {}

extension __Set: Sendable where S: Sendable & ~Copyable {}

extension __Set where S: ~Copyable {

    @inlinable
    public init<E: Hash.Key & ~Copyable>(minimumCapacity: Index_Primitives.Index<E>.Count = .zero)
    where S == Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear> {
        self.init(store: S(minimumCapacity: minimumCapacity))
    }

    @inlinable
    public init<E: Hash.Key & SendableMetatype>(
        minimumCapacity: Index_Primitives.Index<E>.Count = .zero
    )
    where
        S == Ownership.Shared<
            E, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>
        >
    {
        self.init(
            store: Ownership.Shared(
                Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>(
                    minimumCapacity: minimumCapacity
                )
            )
        )
    }

    @inlinable
    public init<E: Hash.Key & SendableMetatype & ~Copyable>(
        minimumCapacity: Index_Primitives.Index<E>.Count = .zero
    )
    where
        S == Ownership.Shared<
            E, Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>
        >
    {
        self.init(
            store: Ownership.Shared(
                Hash.Indexed<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>(
                    minimumCapacity: minimumCapacity
                )
            )
        )
    }
}
