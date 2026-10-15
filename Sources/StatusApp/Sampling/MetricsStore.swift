import Foundation
import Observation
import MetricsCore

@MainActor
@Observable
final class MetricsStore {
    private(set) var latest: Snapshot?
    private(set) var history = MetricsHistory()
    private(set) var activeAlerts: Set<AlertKind> = []
    var isPopoverOpen = false {
        didSet {
            guard isPopoverOpen != oldValue, loop != nil else { return }
            restartLoop()
        }
    }
    @ObservationIgnored var onAlertEvents: (([AlertEvent]) -> Void)?

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let sampler = Sampler()
    @ObservationIgnored private var engine = AlertEngine()
    @ObservationIgnored private var loop: Task<Void, Never>?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func start() {
        restartLoop()
    }

    private func restartLoop() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let delay = await self.tick()
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    /// Samples once, updates state, and returns the seconds to wait before the next sample.
    private func tick() async -> Double {
        let snap = await sampler.sample(includeProcesses: isPopoverOpen)
        if Task.isCancelled { return 0 }
        latest = snap
        history.record(snap)
        let result = engine.evaluate(snap, config: settings.settings.alerts, now: snap.uptime)
        activeAlerts = result.active
        if !result.events.isEmpty { onAlertEvents?(result.events) }
        return isPopoverOpen ? 1 : settings.settings.refreshInterval
    }
}
