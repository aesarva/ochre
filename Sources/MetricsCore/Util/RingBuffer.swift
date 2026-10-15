/// Fixed-capacity buffer that overwrites the oldest element when full.
public struct RingBuffer<Element: Sendable>: Sendable {
    public let capacity: Int
    private var storage: [Element] = []
    /// Index of the oldest element once `storage` has reached `capacity`.
    private var head = 0

    public init(capacity: Int) {
        precondition(capacity > 0, "RingBuffer capacity must be positive")
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    public var count: Int { storage.count }

    public mutating func append(_ element: Element) {
        if storage.count < capacity {
            storage.append(element)
        } else {
            storage[head] = element
            head = (head + 1) % capacity
        }
    }

    /// Elements ordered from oldest to newest.
    public var elements: [Element] {
        Array(storage[head...] + storage[..<head])
    }

    public var last: Element? {
        storage.isEmpty ? nil : storage[(head + storage.count - 1) % storage.count]
    }
}
