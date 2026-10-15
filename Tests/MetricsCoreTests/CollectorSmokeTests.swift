import Testing
import Foundation
@testable import MetricsCore

@Suite struct CollectorSmokeTests {
    @Test func cpu() async throws {
        var c = CPUCollector()
        #expect(c.sample() == nil)
        try await Task.sleep(for: .milliseconds(300))
        let second = c.sample()
        let s = try #require(second)
        #expect((0...100).contains(s.totalPercent))
        #expect(s.cores.count == Sysctl.int("hw.ncpu"))
        #expect(s.clusters.count == (Sysctl.int("hw.nperflevels") ?? 1))
        #expect(s.clusters.allSatisfy { !$0.name.isEmpty })
    }

    @Test func memory() throws {
        let m = try #require(MemoryCollector().sample())
        #expect(m.total == UInt64(Sysctl.int("hw.memsize") ?? 0))
        #expect(m.used > 0 && m.used <= m.total)
        #expect(m.pressure != nil)
    }
}
