import Testing
import Foundation
@testable import MetricsCore

@Suite struct AlertEngineTests {
    func cpu(_ p: Double, at t: TimeInterval) -> Snapshot {
        var s = Snapshot(uptime: t)
        s.cpu = CPUStats(totalPercent: p, clusters: [], cores: []); return s
    }
    @Test func sustainedLoadFiresOnceThenCooldown() {
        var e = AlertEngine(); let cfg = AlertConfig.default
        for t in stride(from: 0.0, to: 60, by: 2) {
            let r = e.evaluate(cpu(95, at: t), config: cfg, now: t)
            #expect(r.active.isEmpty); #expect(r.events.isEmpty)
        }
        let fired = e.evaluate(cpu(95, at: 60), config: cfg, now: 60)
        #expect(fired.active == [.cpuLoad]); #expect(fired.events.map(\.kind) == [.cpuLoad])
        #expect(fired.events[0].title == "Высокая нагрузка CPU")
        #expect(fired.events[0].body == "Загрузка CPU 95 % дольше 60 с")
        var t = 62.0
        while t < 660 { #expect(e.evaluate(cpu(95, at: t), config: cfg, now: t).events.isEmpty); t += 2 }
        #expect(e.evaluate(cpu(95, at: 660), config: cfg, now: 660).events.count == 1)
    }
    @Test func dropBelowThresholdResets() {
        var e = AlertEngine(); let cfg = AlertConfig.default
        _ = e.evaluate(cpu(95, at: 0), config: cfg, now: 0)
        _ = e.evaluate(cpu(50, at: 10), config: cfg, now: 10)
        for t in stride(from: 12.0, through: 70, by: 2) { _ = e.evaluate(cpu(95, at: t), config: cfg, now: t) }
        #expect(e.evaluate(cpu(95, at: 71), config: cfg, now: 71).active.isEmpty)   // 12…71 < 60 с
    }
    @Test func nilValueResets() {
        var e = AlertEngine(); let cfg = AlertConfig.default
        for t in stride(from: 0.0, to: 50, by: 2) { _ = e.evaluate(cpu(95, at: t), config: cfg, now: t) }
        _ = e.evaluate(Snapshot(uptime: 50), config: cfg, now: 50)
        #expect(e.evaluate(cpu(95, at: 62), config: cfg, now: 62).active.isEmpty)
    }
    @Test func gapResetsSustainedTimer() {
        var e = AlertEngine(); let cfg = AlertConfig.default
        _ = e.evaluate(cpu(95, at: 0), config: cfg, now: 0)
        #expect(e.evaluate(cpu(95, at: 100), config: cfg, now: 100).active.isEmpty)   // сон 100 с
    }
    @Test func disabledRuleNeverFires() {
        var cfg = AlertConfig.default; cfg.rules[.cpuLoad]?.enabled = false
        var e = AlertEngine()
        for t in stride(from: 0.0, through: 120, by: 2) {
            #expect(e.evaluate(cpu(99, at: t), config: cfg, now: t).active.isEmpty)
        }
    }
    @Test func immediateRules() {
        var s = Snapshot(uptime: 0)
        s.memory = MemoryStats(total: 1, used: 1, app: 1, wired: 0, compressed: 0, cached: 0,
                               swapUsed: 0, swapTotal: 0, pressure: .critical)
        s.disk = DiskStats(readPerSecond: nil, writePerSecond: nil, volumes: [],
                           systemVolumeAvailable: 5 * 1_073_741_824)
        var e = AlertEngine()
        let r = e.evaluate(s, config: .default, now: 0)
        #expect(r.active == [.memoryPressure, .diskSpace]); #expect(r.events.count == 2)
        #expect(r.events.map(\.kind) == [.memoryPressure, .diskSpace])
        #expect(r.events[1].body == "Свободно \(Format.bytes(5 * 1_073_741_824)) на системном томе")
    }
    @Test func flappingConditionRespectsCooldown() {
        func mem(_ pressure: MemoryPressure, at t: TimeInterval) -> Snapshot {
            var s = Snapshot(uptime: t)
            s.memory = MemoryStats(total: 1, used: 1, app: 1, wired: 0, compressed: 0, cached: 0,
                                   swapUsed: 0, swapTotal: 0, pressure: pressure)
            return s
        }
        var e = AlertEngine(); var events = 0
        for (i, t) in stride(from: 0.0, to: 600, by: 2).enumerated() {
            let r = e.evaluate(mem(i.isMultiple(of: 2) ? .critical : .warning, at: t), config: .default, now: t)
            events += r.events.count
        }
        #expect(events == 1)   // давление прыгает critical/warning каждые 2 с — одно уведомление за 10 минут
        #expect(e.evaluate(mem(.critical, at: 600), config: .default, now: 600).events.count == 1)
    }
    @Test func raisingThresholdRestartsSustainedTimer() {
        var e = AlertEngine(); var cfg = AlertConfig.default
        for t in stride(from: 0.0, through: 50, by: 2) { _ = e.evaluate(cpu(92, at: t), config: cfg, now: t) }
        cfg.rules[.cpuLoad]?.threshold = 95
        for t in stride(from: 52.0, through: 70, by: 2) {
            #expect(e.evaluate(cpu(99, at: t), config: cfg, now: t).active.isEmpty)   // 99 > 95 всего 18 с
        }
    }
    @Test func changingDurationKeepsSustainedTimer() {
        var e = AlertEngine(); var cfg = AlertConfig.default
        for t in stride(from: 0.0, through: 40, by: 2) { _ = e.evaluate(cpu(95, at: t), config: cfg, now: t) }
        cfg.rules[.cpuLoad]?.duration = 30
        #expect(e.evaluate(cpu(95, at: 42), config: cfg, now: 42).active == [.cpuLoad])
    }
    @Test func configEncodesRulesAsJSONObject() throws {
        let data = try JSONEncoder().encode(AlertConfig.default)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect((obj?["rules"] as? [String: Any])?.count == 4)
        #expect(try JSONDecoder().decode(AlertConfig.self, from: data) == .default)
    }
}
