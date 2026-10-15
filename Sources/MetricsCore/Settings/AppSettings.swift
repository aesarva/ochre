import Foundation

/// Menu bar elements. Case order is the display order in the menu bar.
public enum MenuBarItem: String, CaseIterable, Codable, Sendable {
    case icon, cpuGraph, cpuPercent, memoryPercent, temperature, network
}

public struct AppSettings: Codable, Sendable, Equatable {
    public var refreshInterval: Double
    public var menuBarItems: Set<MenuBarItem>
    public var alerts: AlertConfig

    public static let allowedIntervals: [Double] = [1, 2, 5]
    static let defaultInterval: Double = 2
    static let defaultItems: Set<MenuBarItem> = [.icon, .temperature]

    public static let `default` = AppSettings(
        refreshInterval: defaultInterval, menuBarItems: defaultItems, alerts: .default)

    public init(refreshInterval: Double, menuBarItems: Set<MenuBarItem>, alerts: AlertConfig) {
        self.refreshInterval = refreshInterval
        self.menuBarItems = menuBarItems
        self.alerts = alerts
    }

    private enum CodingKeys: String, CodingKey {
        case refreshInterval, menuBarItems, alerts
    }

    /// Lenient: each field falls back to its default independently.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let interval = (try? c.decodeIfPresent(Double.self, forKey: .refreshInterval)) ?? Self.defaultInterval
        refreshInterval = Self.allowedIntervals.contains(interval) ? interval : Self.defaultInterval
        menuBarItems = (try? c.decodeIfPresent(Set<MenuBarItem>.self, forKey: .menuBarItems)) ?? Self.defaultItems
        alerts = (try? c.decodeIfPresent(AlertConfig.self, forKey: .alerts)) ?? .default
    }

    public static func decode(_ data: Data?) -> AppSettings {
        guard let data, let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    public func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }
}
