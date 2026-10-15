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
        #expect(segs == [.text("CPU 23%", highlighted: false), .text("91°", highlighted: true)])
    }
    @Test func emptyItemsShowIcon() {
        #expect(MenuBarContent.segments(items: [], snapshot: nil, cpuHistory: [], active: []) == [.icon])
    }
    @Test func missingValuesShowDash() {
        #expect(MenuBarContent.segments(items: [.memoryPercent], snapshot: snap(), cpuHistory: [], active: [])
                == [.text("RAM —", highlighted: false)])
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
    @Test func hidesTilesWithoutData() {
        var s = snap(); s.sensors = nil
        #expect(OverviewTile.visible(in: s) == [.cpu])
        #expect(OverviewTile.visible(in: nil) == [.cpu, .memory, .temperature, .gpu, .network, .disk])
    }
    @Test func networkTextAndOrder() {
        var s = snap()
        s.network = NetworkStats(interface: "en0", downPerSecond: 2_516_582, upPerSecond: 122_880, totalDown: 0, totalUp: 0)
        let segs = MenuBarContent.segments(items: [.network, .icon, .cpuPercent], snapshot: s, cpuHistory: [], active: [])
        #expect(segs == [.icon, .text("CPU 23%", highlighted: false), .text("↓2.4M ↑120K", highlighted: false)])
    }
    @Test func emptyItemsWithHiddenAlertShowsIconAndWarning() {
        let segs = MenuBarContent.segments(items: [], snapshot: nil, cpuHistory: [], active: [.diskSpace])
        #expect(segs == [.icon, .text("⚠", highlighted: true)])
    }
    @Test func highlightedVisibleSegmentSuppressesWarning() {
        let segs = MenuBarContent.segments(items: [.memoryPercent], snapshot: nil, cpuHistory: [], active: [.memoryPressure])
        #expect(segs == [.text("RAM —", highlighted: true)])
    }
}
