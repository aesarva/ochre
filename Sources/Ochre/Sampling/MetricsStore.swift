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
    @ObservationIgnored private var observedInterval: Double?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func start() {
        guard loop == nil else { return }
        observedInterval = settings.settings.refreshInterval
        restartLoop()
        observeRefreshInterval()
    }

    /// Restarts the sampling loop as soon as the user picks another refresh interval.
    private func observeRefreshInterval() {
        withObservationTracking {
            _ = settings.settings.refreshInterval
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                let interval = self.settings.settings.refreshInterval
                if interval != self.observedInterval {
                    self.observedInterval = interval
                    self.restartLoop()
                }
                self.observeRefreshInterval()
            }
        }
    }

    private func restartLoop() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let delay = await self?.tick() else { return }
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
        return SamplingCadence.interval(popoverOpen: isPopoverOpen, setting: settings.settings.refreshInterval)
    }
}
