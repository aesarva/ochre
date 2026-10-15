import AppKit
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

    /// Цвет шкалы для текста. Светлые ступени (янтарь, угли) в светлой теме затемняются вдвое —
    /// иначе на светлом стекле они не читаются; «жар» и тёмная тема остаются как есть.
    var textColor: Color {
        guard case let .rgb(r, g, b) = self else { return .primary }
        guard 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.45 else { return swiftUIColor }
        return Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let k = dark ? 1.0 : 0.5
            return NSColor(srgbRed: r * k, green: g * k, blue: b * k, alpha: 1)
        })
    }
}

extension Color {
    /// «Жар» — цвет сработавшего оповещения.
    static let heatHot = HeatScale.hot.swiftUIColor
}
