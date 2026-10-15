import MetricsCore
import SwiftUI

/// Составная горизонтальная полоса в оттенках основного цвета с легендой 2×2.
struct StackedBar: View {
    let segments: [(label: String, value: Double)]
    let total: Double
    var format: (Double) -> String = { Format.bytes(UInt64(max($0, 0))) }

    private static let opacities: [Double] = [1.0, 0.7, 0.45, 0.25]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 1.5) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { i, s in
                        Rectangle()
                            .fill(Color.primary.opacity(Self.opacity(i)))
                            .frame(width: max(0, geo.size.width * s.value / max(total, 1)))
                    }
                    Spacer(minLength: 0)
                }
                .background(Color.primary.opacity(0.08))
                .clipShape(Capsule())
            }
            .frame(height: 10)
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                ForEach(0..<(segments.count + 1) / 2, id: \.self) { row in
                    GridRow {
                        legend(row * 2)
                        if row * 2 + 1 < segments.count { legend(row * 2 + 1) }
                    }
                }
            }
            .font(.system(size: 11).monospacedDigit())
        }
    }

    private static func opacity(_ i: Int) -> Double { opacities[min(i, opacities.count - 1)] }

    private func legend(_ i: Int) -> some View {
        HStack(spacing: 5) {
            Circle().fill(Color.primary.opacity(Self.opacity(i))).frame(width: 7, height: 7)
            Text(segments[i].label).foregroundStyle(.secondary)
            Text(format(segments[i].value))
        }
    }
}
