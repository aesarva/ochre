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

    @Test func sampler() async throws {
        let s = Sampler()
        _ = await s.sample(includeProcesses: true)
        try await Task.sleep(for: .milliseconds(300))
        let clock = ContinuousClock()
        var snap = Snapshot(uptime: 0)
        let withProcesses = await clock.measure { snap = await s.sample(includeProcesses: true) }
        #expect(snap.cpu != nil); #expect(snap.memory != nil); #expect(snap.processes != nil)
        var light = Snapshot(uptime: 0)
        let without = await clock.measure { light = await s.sample(includeProcesses: false) }
        #expect(light.processes == nil)
        print("sampler timing: includeProcesses=true \(withProcesses), false \(without)")
    }

    @Test func network() async throws {
        var n = NetworkCollector()
        _ = n.sample(now: MonotonicClock.now())
        try await Task.sleep(for: .milliseconds(300))
        let second = n.sample(now: MonotonicClock.now())
        let s = try #require(second)
        #expect((s.downPerSecond ?? 0) >= 0 && (s.upPerSecond ?? 0) >= 0)
    }

    @Test func disk() throws {
        var d = DiskCollector()
        let first = d.sample(now: MonotonicClock.now())
        let s = try #require(first)
        #expect(s.readPerSecond == nil)          // первый замер
        #expect(s.volumes.contains { $0.path == "/" })
        #expect((s.systemVolumeAvailable ?? 0) > 0)
    }

    @Test func gpu() {
        if let g = GPUCollector().sample() { #expect((0...100).contains(g.utilizationPercent)) }
    }

    @Test func battery() {
        if let b = BatteryCollector().sample() { #expect((0...100).contains(b.percent)) }
    }

    /// Датчиков может не быть (виртуальная машина, CI) — тогда проверять нечего, как и в приложении.
    @Test func sensors() {
        guard let s = SensorCollector().sample() else { return }
        if let cpu = s.cpuCelsius { #expect((10...120).contains(cpu)) }
        #expect(s.temperatures.allSatisfy { $0.celsius > 0 && $0.celsius < 150 })
    }

    @Test func processes() async throws {
        var p = ProcessCollector()
        _ = p.sample(now: MonotonicClock.now())
        try await Task.sleep(for: .milliseconds(300))
        let second = p.sample(now: MonotonicClock.now())
        let rows = try #require(second)
        #expect(Double(ProcessCollector.allPids().count) >= Double(proc_listallpids(nil, 0)) * 0.9)
        #expect(rows.contains { $0.pid == getpid() })
        #expect(rows.allSatisfy { !$0.name.isEmpty })
    }
}

@Suite struct EffectiveLevelsTests {
    @Test func matchingPassesThrough() {
        let levels = [PerfLevel(index: 0, name: "Super", coreCount: 6),
                      PerfLevel(index: 1, name: "Performance", coreCount: 12)]
        let r = CPUCollector.effectiveLevels(levels, coreCount: 18)
        #expect(r.map(\.name) == ["Super", "Performance"])
        #expect(r.map(\.coreCount) == [6, 12])
    }

    @Test func mismatchFallsBackToCPU() {
        let levels = [PerfLevel(index: 0, name: "Super", coreCount: 0),
                      PerfLevel(index: 1, name: "Performance", coreCount: 12)]
        let r = CPUCollector.effectiveLevels(levels, coreCount: 18)
        #expect(r.count == 1 && r[0].name == "CPU" && r[0].index == 0 && r[0].coreCount == 18)
    }

    @Test func emptyFallsBackToCPU() {
        let r = CPUCollector.effectiveLevels([], coreCount: 8)
        #expect(r.count == 1 && r[0].name == "CPU" && r[0].coreCount == 8)
    }
}
