import MetricsCore
import SwiftUI

extension HeatColor {
    /// «Холодное стекло» — системный основной цвет с прозрачностью 12 %, остальное — RGB шкалы.
    var swiftUIColor: Color {
        switch self {
        case .cold: Color.primary.opacity(0.12)
        case let .rgb(r, g, b): Color(.sRGB, red: r, green: g, blue: b)
        }
    }
}

extension Color {
    /// «Жар» — цвет сработавшего оповещения.
    static let heatHot = HeatScale.hot.swiftUIColor
}
