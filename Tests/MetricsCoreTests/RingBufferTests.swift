import Testing
@testable import MetricsCore

@Suite struct RingBufferTests {
    @Test func appendsInOrder() {
        var b = RingBuffer<Int>(capacity: 3)
        b.append(1); b.append(2)
        #expect(b.elements == [1, 2]); #expect(b.count == 2); #expect(b.last == 2)
    }
    @Test func overwritesOldest() {
        var b = RingBuffer<Int>(capacity: 3)
        for i in 1...5 { b.append(i) }
        #expect(b.elements == [3, 4, 5]); #expect(b.count == 3)
    }
    @Test func emptyHasNoLast() {
        #expect(RingBuffer<Int>(capacity: 2).last == nil)
    }
    @Test func monotonicClockAdvances() {
        let a = MonotonicClock.now(); let b = MonotonicClock.now()
        #expect(b >= a); #expect(a > 0)
    }
}
