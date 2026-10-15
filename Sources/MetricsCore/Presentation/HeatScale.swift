/// Цвет шкалы нагрева: «холодное стекло» (рисуется системным цветом) или RGB с компонентами 0…1.
public enum HeatColor: Equatable, Sendable {
    case cold
    case rgb(red: Double, green: Double, blue: Double)
}

/// Ступени шкалы — для значений, окрашиваемых ступенчато (температуры, давление памяти).
public enum HeatLevel: Int, Sendable, Comparable {
    case neutral, amber, ember, hot

    public var color: HeatColor {
        switch self {
        case .neutral: .cold
        case .amber: HeatScale.amber
        case .ember: HeatScale.ember
        case .hot: HeatScale.hot
        }
    }

    public static func < (a: HeatLevel, b: HeatLevel) -> Bool { a.rawValue < b.rawValue }
}

/// Цвет цифр на плитке табло.
public enum TileInk: Sendable { case light, dark }

/// Единственная хроматическая палитра интерфейса: цвет означает нагрев. Горчичная, как на сайте.
public enum HeatScale {
    public static let amber = HeatColor.rgb(red: 227 / 255, green: 191 / 255, blue: 92 / 255)
    public static let ember = HeatColor.rgb(red: 204 / 255, green: 143 / 255, blue: 37 / 255)
    public static let hot = HeatColor.rgb(red: 180 / 255, green: 70 / 255, blue: 42 / 255)

    /// Плитка табло: на графите (холодно) и ближе к «жару» цифры светлые, на янтаре и углях — тёмные.
    /// С 83 % смесь углей и жара темнеет настолько, что светлые цифры контрастнее тёмных.
    public static func tileInk(forLoad load: Double) -> TileInk {
        guard load.isFinite, load >= 20, load < 83 else { return .light }
        return .dark
    }

    /// Загрузка 0…100 %: < 20 — холодное стекло, 20→60 Янтарь→Угли, 60→90 Угли→Жар, ≥ 90 — Жар.
    public static func color(forLoad load: Double) -> HeatColor {
        guard load.isFinite else { return .cold }
        let l = min(max(load, 0), 100)
        switch l {
        case ..<20: return .cold
        case ..<60: return mix(amber, ember, (l - 20) / 40)
        case ..<90: return mix(ember, hot, (l - 60) / 30)
        default: return hot
        }
    }

    /// Доля 0…1 для полосок (100 % = одно ядро); вне диапазона и NaN обрезаются.
    public static func fraction(_ load: Double) -> Double {
        guard load.isFinite else { return 0 }
        return min(max(load, 0), 100) / 100
    }

    /// Температура: < 60° нейтрально, 60–80° янтарь, 80–95° угли, ≥ 95° жар.
    public static func temperatureLevel(_ celsius: Double) -> HeatLevel {
        switch celsius {
        case ..<60: .neutral
        case ..<80: .amber
        case ..<95: .ember
        default: .hot
        }
    }

    private static func mix(_ a: HeatColor, _ b: HeatColor, _ t: Double) -> HeatColor {
        guard case let .rgb(r1, g1, b1) = a, case let .rgb(r2, g2, b2) = b else { return a }
        return .rgb(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t)
    }
}
