import Testing
import Foundation
@testable import MetricsCore

@Suite struct ProcessCPUTrackerTests {
    @Test func computesPercent() {
        var t = ProcessCPUTracker()
        #expect(t.update([.init(pid: 1, startTime: 7, cpuTimeNanos: 0)], at: 0).isEmpty)
        #expect(t.update([.init(pid: 1, startTime: 7, cpuTimeNanos: 1_500_000_000)], at: 1) == [1: 150])
    }
    @Test func pidReuseGivesNil() {
        var t = ProcessCPUTracker()
        _ = t.update([.init(pid: 1, startTime: 7, cpuTimeNanos: 5_000_000_000)], at: 0)
        #expect(t.update([.init(pid: 1, startTime: 9, cpuTimeNanos: 100)], at: 1)[1] == nil)
        #expect(t.update([.init(pid: 1, startTime: 9, cpuTimeNanos: 500_000_100)], at: 2) == [1: 50])
    }
    @Test func forgetsExitedProcesses() {
        var t = ProcessCPUTracker()
        _ = t.update([.init(pid: 1, startTime: 1, cpuTimeNanos: 0)], at: 0)
        _ = t.update([], at: 1)
        #expect(t.update([.init(pid: 1, startTime: 1, cpuTimeNanos: 10)], at: 2).isEmpty)
    }
}
