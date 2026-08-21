public import Index_Primitives
public import Set_Primitive
public import Store_Protocol_Primitives

extension __Set where S: Store.`Protocol` & ~Copyable {

    public typealias Index = Index_Primitives.Index<S.Element>
}
