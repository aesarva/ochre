import Testing
import Foundation
@testable import MetricsCore

@Suite struct MetricsHistoryTests {
    func s(_ t: TimeInterval, cpu: Double?) -> Snapshot {
        var x = Snapshot(uptime: t)
        if let cpu { x.cpu = CPUStats(totalPercent: cpu, clusters: [ClusterLoad(level: 0, name: "Super", percent: cpu)], cores: []) }
        return x
    }
    @Test func recordsAndTrimsByTime() {
        var h = MetricsHistory(window: 10, capacity: 100)
        for t in 0...20 { h.record(s(Double(t), cpu: Double(t))) }
        #expect(h.points(.cpuTotal, now: 20).map(\.value) == (10...20).map(Double.init))
        #expect(h.points(.cluster(0), now: 20).count == 11)
    }
    @Test func skipsNil() {
        var h = MetricsHistory()
        h.record(s(0, cpu: 5)); h.record(s(1, cpu: nil))
        #expect(h.points(.cpuTotal, now: 1) == [HistoryPoint(t: 0, value: 5)])
    }
    @Test func historySurvivesIntervalChange() {
        var h = MetricsHistory()
        for t in stride(from: 0.0, to: 300, by: 2) { h.record(s(t, cpu: 1)) }    // 2 с
        for t in stride(from: 300.0, to: 360, by: 1) { h.record(s(t, cpu: 2)) }  // панель открыта, 1 с
        for t in stride(from: 360.0, to: 400, by: 2) { h.record(s(t, cpu: 3)) }  // снова 2 с
        let p = h.points(.cpuTotal, now: 398)
        #expect(p.first?.t == 0); #expect(p.count == 150 + 60 + 20)
    }
}
