public import Index_Primitives

extension __SetProtocol where Self: ~Copyable {

    @inlinable
    public var isEmpty: Bool { count == .zero }
}
