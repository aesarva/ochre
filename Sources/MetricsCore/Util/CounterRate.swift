import Foundation

/// Converts a monotonically growing counter into a per-second rate.
public struct CounterRate: Sendable {
    private struct Sample: Sendable {
        let counter: UInt64
        let time: TimeInterval
    }

    private var last: Sample?

    public init() {}

    /// Returns units per second since the previous sample, or `nil` when there is no
    /// usable baseline (first call, non-positive elapsed time, or a counter that went down).
    /// The new sample always becomes the baseline for the next call.
    public mutating func update(_ counter: UInt64, at time: TimeInterval) -> Double? {
        defer { last = Sample(counter: counter, time: time) }
        guard let last, counter >= last.counter else { return nil }
        let elapsed = time - last.time
        guard elapsed > 0 else { return nil }
        return Double(counter - last.counter) / elapsed
    }
}
