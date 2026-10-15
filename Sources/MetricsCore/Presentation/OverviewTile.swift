import Foundation

public enum OverviewTile: CaseIterable, Sendable {
    case cpu, memory, temperature, gpu, network, disk, battery

    /// Tiles shown for a snapshot. Before the first snapshot everything except the battery is shown.
    public static func visible(in snapshot: Snapshot?) -> [OverviewTile] {
        allCases.filter { tile in
            guard let snapshot else { return tile != .battery }
            switch tile {
            case .cpu: return snapshot.cpu != nil
            case .memory: return snapshot.memory != nil
            case .temperature: return snapshot.sensors?.cpuCelsius != nil
            case .gpu: return snapshot.gpu != nil
            case .network: return snapshot.network != nil
            case .disk: return snapshot.disk != nil
            case .battery: return snapshot.battery != nil
            }
        }
    }
}
