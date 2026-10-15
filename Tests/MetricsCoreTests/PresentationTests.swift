import Testing
import Foundation
@testable import MetricsCore

@Suite struct PresentationTests {
    func snap() -> Snapshot {
        var s = Snapshot(uptime: 0)
        s.cpu = CPUStats(totalPercent: 23.4, clusters: [], cores: [])
        s.sensors = SensorStats(temperatures: [], cpuCelsius: 91.2, gpuCelsius: nil, fans: [], systemPowerWatts: nil)
        return s
    }
    @Test func defaultSegmentsWithHighlight() {
        let segs = MenuBarContent.segments(items: [.cpuPercent, .temperature], snapshot: snap(),
                                           cpuHistory: [], active: [.cpuTemperature])
        #expect(segs == [.text("CPU 23%", highlighted: false, widthTemplate: "CPU 100%"),
                         .text("91°", highlighted: true, widthTemplate: "100°")])
    }
    @Test func emptyItemsShowIcon() {
        #expect(MenuBarContent.segments(items: [], snapshot: nil, cpuHistory: [], active: []) == [.miniDie([])])
    }
    @Test func missingValuesShowDash() {
        #expect(MenuBarContent.segments(items: [.memoryPercent], snapshot: snap(), cpuHistory: [], active: [])
                == [.text("RAM —", highlighted: false, widthTemplate: "RAM 100%")])
    }
    @Test func hiddenAlertAddsWarning() {
        let segs = MenuBarContent.segments(items: [.cpuPercent], snapshot: snap(), cpuHistory: [], active: [.diskSpace])
        #expect(segs.last == .text("⚠", highlighted: true))
    }
    @Test func graphUsesLastTen() {
        let segs = MenuBarContent.segments(items: [.cpuGraph], snapshot: nil,
                                           cpuHistory: (1...15).map(Double.init), active: [])
        #expect(segs == [.cpuGraph((6...15).map(Double.init))])
    }
    @Test func networkTextAndOrder() {
        var s = snap()
        s.network = NetworkStats(interface: "en0", downPerSecond: 2_516_582, upPerSecond: 122_880, totalDown: 0, totalUp: 0)
        let segs = MenuBarContent.segments(items: [.network, .icon, .cpuPercent], snapshot: s, cpuHistory: [], active: [])
        #expect(segs == [.miniDie([]), .text("CPU 23%", highlighted: false, widthTemplate: "CPU 100%"),
                         .text("↓2.4M ↑120K", highlighted: false, widthTemplate: "↓1023M ↑1023M")])
    }
    @Test func storedIconItemRendersMiniDie() {
        var s = Snapshot(uptime: 0)
        s.cpu = CPUStats(totalPercent: 10, clusters: [ClusterLoad(level: 0, name: "Super", percent: 10)],
                         cores: [CoreLoad(index: 0, level: 0, percent: 10), CoreLoad(index: 1, level: 0, percent: 80)])
        let segs = MenuBarContent.segments(items: [.icon], snapshot: s, cpuHistory: [], active: [])
        // 2 ядра, 1 кластер: наименьшее c с ≤ 3 рядами — c = 1, т.е. столбик
        #expect(segs == [.miniDie([MiniDieCell(row: 0, column: 0, load: 10), MiniDieCell(row: 1, column: 0, load: 80)])])
    }
    @Test func miniDieWithoutCPUFallsBackToEmptyGrid() {
        #expect(MenuBarContent.segments(items: [], snapshot: nil, cpuHistory: [], active: []) == [.miniDie([])])
    }
    @Test func emptyItemsWithHiddenAlertShowsIconAndWarning() {
        let segs = MenuBarContent.segments(items: [], snapshot: nil, cpuHistory: [], active: [.diskSpace])
        #expect(segs == [.miniDie([]), .text("⚠", highlighted: true)])
    }
    @Test func highlightedVisibleSegmentSuppressesWarning() {
        let segs = MenuBarContent.segments(items: [.memoryPercent], snapshot: nil, cpuHistory: [], active: [.memoryPressure])
        #expect(segs == [.text("RAM —", highlighted: true, widthTemplate: "RAM 100%")])
    }
    @Test func spokenLabelJoinsVisibleValues() {
        let segs: [MenuBarSegment] = [.miniDie([]), .cpuGraph([1]), .text("CPU 23%", highlighted: false, widthTemplate: "CPU 100%"),
                                      .text("91°", highlighted: true, widthTemplate: "100°")]
        #expect(MenuBarContent.spokenLabel(segs) == "StatusApp, CPU 23%, 91°")
    }
}
